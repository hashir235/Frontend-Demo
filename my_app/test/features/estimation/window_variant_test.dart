import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/window_catalog.dart';
import 'package:my_app/features/estimation/models/collar_layout.dart';
import 'package:my_app/features/estimation/models/optimization_request.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/models/window_variant.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_handler.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/window_cut_calculator.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';
import 'package:my_app/features/formulas/model/formula_window_key.dart';

/// The Prime (B frame) and Royal (BA frame) windows: each the sliding window
/// it is made like, with DC30C and DC26C swapped for its own frame and every
/// formula exactly the C profiles' -- never the collar (F) ones -- in the one
/// collar type it comes in, collar 2, no collar on any side.
void main() {
  final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(
    jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final FormulaBook book = FormulaBook(catalogue, FormulaOverrides.empty());

  List<WindowType> leaves(List<WindowType> nodes) => <WindowType>[
    for (final WindowType node in nodes)
      if (node.children.isEmpty) node else ...leaves(node.children),
  ];

  const Map<String, String> bFrame = <String, String>{'DC30C': 'DC30B', 'DC26C': 'DC26B'};
  const Map<String, String> baFrame = <String, String>{'DC30C': 'DC30BA', 'DC26C': 'DC26BA'};

  test('sixteen variants: eight sliding windows on each frame, no M-section', () {
    expect(WindowVariants.all, hasLength(16));
    final Set<String> codes = <String>{};
    for (final WindowVariant v in WindowVariants.all) {
      expect(codes.add(v.code), isTrue, reason: 'one ${v.code}');
      expect(v.baseCode.startsWith('M'), isFalse, reason: 'no M-section base');
      expect(v.collars, <int>[2], reason: 'collar 2 only, as confirmed so far');
      expect(v.sections, v.frame == 'B' ? bFrame : baFrame);
      expect(v.sections.keys.any((String s) => s.endsWith('F')), isFalse,
          reason: 'the collar profiles are never renamed onto these frames');
    }
    // Every one of them is in the library, once, and no plain window is a
    // variant by accident.
    final List<String> inLibrary = <String>[
      for (final WindowType n in leaves(WindowCatalog.root)) n.codeName!,
    ];
    for (final WindowVariant v in WindowVariants.all) {
      expect(inLibrary.where((String c) => c == v.code), hasLength(1));
      expect(inLibrary, contains(v.baseCode));
    }
    expect(inLibrary.toSet(), hasLength(inLibrary.length), reason: 'no code twice');
  });

  test('names on the bill are all different', () {
    final List<String> labels = <String>[
      for (final WindowType n in leaves(WindowCatalog.root))
        if (WindowVariants.of(n.codeName) != null) n.label,
    ];
    expect(labels.toSet(), hasLength(labels.length));
    expect(WindowCatalog.allTypeNames, containsAll(labels),
        reason: 'each has its own hardware rate');
  });

  for (final WindowVariant variant in WindowVariants.all) {
    for (final String context in <String>['estimation', 'fabrication']) {
      test('${variant.code} ($context): the base\'s formulas, collar 2, own frame', () {
        final Set<String> dims = catalogue.dimensionsFor(
          '$context/${FormulaWindowKey.engineWindowFor(variant.baseCode, context)!.window}',
        );
        expect(catalogue.dimensionsFor('$context/${variant.code}'), dims);

        // Every lock and rubber the base is cut in, at collar 2.
        final List<({int? lock, String? rubber})> settings = context == 'fabrication'
            ? <({int? lock, String? rubber})>[
                for (final int lock in <int>[1, 2, 3])
                  for (final String rubber in <String>['F', 'U'])
                    (lock: lock, rubber: rubber),
              ]
            : <({int? lock, String? rubber})>[(lock: null, rubber: null)];

        int compared = 0;
        for (final ({int? lock, String? rubber}) s in settings) {
          FormulaWindowKey? keyFor(String code, int collar) => FormulaWindowKey.of(
            context: context,
            appWindowCode: code,
            dimensions: dims,
            collarIndex: collar,
            lockType: s.lock,
            rubberType: s.rubber,
          );
          final FormulaWindowKey baseKey = keyFor(variant.baseCode, 2)!;
          final FormulaWindowKey ownKey = keyFor(variant.code, 2)!;
          expect(ownKey.configKey, baseKey.configKey);

          final List<SectionFormulas>? base = catalogue.shippedFor(baseKey);
          if (base == null) continue; // a lock this window does not take
          final List<SectionFormulas> own = catalogue.shippedFor(ownKey)!;

          final Map<String, SectionFormulas> ownByName = <String, SectionFormulas>{
            for (final SectionFormulas section in own) section.section: section,
          };
          expect(ownByName.keys.toSet(),
              <String>{for (final SectionFormulas b in base) variant.sectionFor(b.section)});
          for (final SectionFormulas b in base) {
            final SectionFormulas o = ownByName[variant.sectionFor(b.section)]!;
            expect(
              <String>[for (final p in o.pieces) '${p.label}=${p.stored}'],
              <String>[for (final p in b.pieces) '${p.label}=${p.stored}'],
              reason: '${o.section} is cut exactly as ${b.section}',
            );
          }
          // The frame is the variant's own, and nothing of the plain or the
          // collar frame is left in it.
          expect(ownByName.keys, containsAll(variant.sections.values));
          for (final String gone in <String>['DC30C', 'DC26C', 'DC30F', 'DC26F']) {
            expect(ownByName.containsKey(gone), isFalse, reason: '$gone in ${variant.code}');
          }

          // The glass is the base's.
          expect(
            <String>[for (final g in catalogue.shippedGlassFor(ownKey)) for (final p in g.pieces) p.stored],
            <String>[for (final g in catalogue.shippedGlassFor(baseKey)) for (final p in g.pieces) p.stored],
          );

          // And no collar it does not come in.
          expect(catalogue.shippedFor(keyFor(variant.code, 1)!), isNull);
          compared++;
        }
        expect(compared, greaterThan(0));

        expect(
          catalogue.frameSectionsFor('$context/${variant.code}'),
          containsAll(variant.sections.values),
          reason: 'measured side by side, the frame still gets its own sides',
        );
      });
    }
  }

  group('cut sizes', () {
    Map<String, double> estimationMargins() => <String, double>{
      'cm_DC30C': 0.041,
      'cm_DC26C': 0.041,
      'cm_DC30F': 0.25,
      'cm_DC26F': 0.25,
    };

    for (final WindowVariant variant in WindowVariants.all) {
      final bool corner = variant.baseCode.startsWith('SC');
      for (final bool fabrication in <bool>[false, true]) {
        test('${variant.code} ${fabrication ? 'fabrication' : 'estimation'}: '
            'the base\'s sizes on its own frame', () {
          WindowCutList cut(String code) => WindowCutCalculator(book).compute(
            WindowCutRequest(
              isFabrication: fabrication,
              appWindowCode: code,
              collarIndex: 2,
              unitMode: fabrication ? 'feet' : 'inches',
              heightValue: fabrication ? '120.5' : '48.4',
              widthValue: fabrication ? '150' : '60',
              rightWidthValue: corner ? (fabrication ? '150' : '60') : null,
              leftWidthValue: corner ? (fabrication ? '110' : '44') : null,
              lockType: fabrication ? 1 : null,
              rubberType: fabrication ? 'F' : null,
            ),
            margins: fabrication ? <String, double>{'cm': 0.3} : estimationMargins(),
          );
          final WindowCutList base = cut(variant.baseCode);
          final WindowCutList own = cut(variant.code);
          expect(base.problems, isEmpty);
          expect(own.problems, isEmpty);
          expect(
            <String>[for (final p in own.pieces) '${p.section} ${p.label} ${p.lengthFt}'],
            <String>[
              for (final p in base.pieces)
                '${variant.sectionFor(p.section)} ${p.label} ${p.lengthFt}',
            ],
          );
          expect(own.glass.map((GlassPiece g) => g.toString()),
              base.glass.map((GlassPiece g) => g.toString()));
        });
      }
    }
  });

  test('the engine is sent the base window, with the variant\'s own pieces', () {
    const OptimizationWindowRequest window = OptimizationWindowRequest(
      winNo: 1,
      windowCode: 'PF3B_win',
      windowLabel: 'Prime Center Fix',
      collarIndex: 2,
      unitMode: 'inches',
      heightValue: '48',
      widthValue: '60',
      rightWidthValue: null,
      leftWidthValue: null,
      archValue: null,
      description: null,
      addBottom: false,
      addTee: false,
      addNet: false,
      backCollarCm: 1.7,
      lockType: null,
      rubberType: null,
      gauge: '',
      color: '',
      glassColor: '',
    );
    final Map<String, Object?> sent = window
        .withComputed(
          <Map<String, Object?>>[
            <String, Object?>{'section': 'DC30B', 'piece': 'WT', 'lengthFt': 5.0},
          ],
          const <Map<String, Object?>>[],
        )
        .toJson();
    expect(sent['windowCode'], 'PF3_win');
    expect(sent['windowLabel'], 'Prime Center Fix', reason: 'its own name on the bill');
    expect((sent['computedPieces'] as List<dynamic>).single['section'], 'DC30B');

    const OptimizationWindowRequest plain = OptimizationWindowRequest(
      winNo: 2,
      windowCode: 'PF3_win',
      windowLabel: 'Center Fix',
      collarIndex: 1,
      unitMode: 'inches',
      heightValue: '48',
      widthValue: '60',
      rightWidthValue: null,
      leftWidthValue: null,
      archValue: null,
      description: null,
      addBottom: false,
      addTee: false,
      addNet: false,
      backCollarCm: 1.7,
      lockType: null,
      rubberType: null,
      gauge: '',
      color: '',
      glassColor: '',
    );
    expect(plain.toJson()['windowCode'], 'PF3_win');
  });

  group('the input screen', () {
    WindowType node(String code) => WindowCatalog.byCodeName(code)!;

    test('collar 2 only, drawn as the base\'s collar 2', () {
      for (final WindowVariant variant in WindowVariants.all) {
        final CollarLayout layout = CollarLayout.forWindow(variant.code)!;
        expect(layout.isFixed, isTrue);
        expect(layout.collars, <int>[2]);
        expect(layout.nearestOffered(1), 2);
        expect(layout.sidesWithCollar(2), isEmpty, reason: 'no collar on any side');
        expect(layout.toggle(2, CollarSide.top), isNull);
        expect(layout.toggleWholeFrame(2), isNull);
        expect(CollarLayout.forWindow(variant.baseCode)!.isFixed, isFalse,
            reason: 'the base keeps every collar');
      }
    });

    test('the sidebar lists the variant\'s own frame; the drawing gets the base\'s names', () {
      final WindowInputHandler own = handlerForWindow(node('SB_win'));
      final WindowInputHandler base = handlerForWindow(node('S_win'));
      expect(own.sectionsByCollar.keys, <int>[2]);
      expect(own.sectionsForCollar(2), <String>['DC30B', 'DC26B', 'D29', 'M23', 'M24', 'M28']);
      expect(base.sectionsForCollar(2), <String>['DC30C', 'DC26C', 'D29', 'M23', 'M24', 'M28']);

      final Widget? drawing = own.overlayForCollar(2, 'DC30B');
      expect((drawing! as dynamic).selectedSection, 'DC30C');
      expect((drawing as dynamic).collarId, 2);

      final WindowInputHandler corner = handlerForWindow(node('SCLBA_win'));
      expect(corner.usesSplitWidthInputs, isTrue, reason: 'a corner is still a corner');
      expect(corner.sectionsForCollar(2), containsAll(<String>['DC30BA', 'DC26BA']));
    });

    test('each is drawn as the window it is made like', () {
      expect(WindowCatalog.drawnAs(node('PS4B_win')).codeName, 'PS4_win');
      final WindowType royalCorners = WindowCatalog.royalWindows
          .firstWhere((WindowType n) => n.label == 'Royal Corner Windows');
      expect(WindowCatalog.drawnAs(royalCorners).label, 'Sliding Corner Windows');
      expect(WindowCatalog.drawnAs(node('S_win')).codeName, 'S_win');
    });
  });
}
