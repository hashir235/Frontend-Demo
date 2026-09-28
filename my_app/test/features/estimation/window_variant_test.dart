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

  final List<WindowVariant> bAndBa = WindowVariants.all
      .where((WindowVariant v) => v.frame == 'B' || v.frame == 'BA')
      .toList();
  final List<WindowVariant> economy =
      WindowVariants.all.where((WindowVariant v) => v.frame == 'E').toList();

  test('codes are one per window', () {
    final Set<String> codes = <String>{};
    for (final WindowVariant v in WindowVariants.all) {
      expect(codes.add(v.code), isTrue, reason: 'one ${v.code}');
    }
  });

  test('sixteen B and BA variants: eight sliding windows on each frame, no M-section', () {
    expect(bAndBa, hasLength(16));
    for (final WindowVariant v in bAndBa) {
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
      expect(inLibrary.where((String c) => c == v.code),
          hasLength(v.isAlternate ? 0 : 1), reason: v.code);
      expect(inLibrary, contains(v.baseCode));
    }
    expect(inLibrary.toSet(), hasLength(inLibrary.length), reason: 'no code twice');
  });

  test('Economy: every sliding window, M-section too, on the profiles as listed', () {
    const Map<String, String> plain = <String, String>{
      'DC30F': 'EC30F',
      'DC26F': 'EC26F',
      'DC30C': 'EC30B',
      'DC26C': 'EC26B',
      'M23': 'EC23',
      'M24': 'EC24',
      'M28': 'EC28',
    };
    const Map<String, String> m = <String, String>{
      'M30F': 'ET30',
      'M26F': 'ET26',
      'M30': 'ET30A',
      'M26': 'ET26A',
      'M23': 'ET23',
      'M24': 'ET24',
      'M28': 'ET28',
    };
    final List<WindowVariant> onCards =
        economy.where((WindowVariant v) => !v.isAlternate).toList();
    final List<WindowVariant> switched =
        economy.where((WindowVariant v) => v.isAlternate).toList();
    expect(onCards, hasLength(16));
    expect(switched, hasLength(8), reason: 'an ET24A twin for each M-section one');
    for (final WindowVariant v in economy) {
      expect(v.collars, isNull, reason: 'every collar of its base');
      final bool isM = v.baseCode.startsWith('M');
      if (!isM) {
        expect(v.sections, plain);
        expect(v.alternateCode, isNull);
        continue;
      }
      expect(v.sections, <String, String>{...m, if (v.isAlternate) 'M24': 'ET24A'});
      final WindowVariant pair = WindowVariants.of(v.alternateCode)!;
      expect(pair.alternateCode, v.code, reason: 'the pair points both ways');
      expect(pair.isAlternate, !v.isAlternate);
      expect(pair.baseCode, v.baseCode);
      expect(WindowVariants.libraryCode(v.code), v.isAlternate ? pair.code : v.code);
      expect(WindowVariants.alternateProfile(v.code),
          v.isAlternate ? (own: 'ET24A', other: 'ET24') : (own: 'ET24', other: 'ET24A'));
    }
    final WindowGroup group = WindowCatalog.groupsForFlow(isFabrication: false)
        .firstWhere((WindowGroup g) => g.id == 'economy');
    expect(group.title, 'Economy Sliding Window');
    expect(group.rows.single.nodes.map((WindowType n) => n.label), <String>[
      'Eco Sliding Window',
      'Eco Sliding Window M_Section',
      'Eco Panel Windows',
      'Eco Panel Windows M_Section',
      'Eco Corner Windows',
      'Eco Corner Windows M_Section',
    ]);
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
      test('${variant.code} ($context): the base\'s formulas, its collars, own profiles', () {
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
          for (int collar = 1; collar <= 14; collar++) {
          final FormulaWindowKey baseKey = keyFor(variant.baseCode, collar)!;
          final FormulaWindowKey ownKey = keyFor(variant.code, collar)!;
          expect(ownKey.configKey, baseKey.configKey);

          final List<SectionFormulas>? base = catalogue.shippedFor(baseKey);
          if (base == null) continue; // a lock or collar this window does not take
          if (!variant.offersCollar(collar)) {
            expect(catalogue.shippedFor(ownKey), isNull,
                reason: 'no collar $collar on ${variant.code}');
            continue;
          }
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
          // Nothing it renames is left under the old name.
          for (final MapEntry<String, String> swap in variant.sections.entries) {
            if (swap.key == swap.value) continue;
            expect(ownByName.containsKey(swap.key), isFalse,
                reason: '${swap.key} in ${variant.code}');
          }

          // The glass is the base's.
          expect(
            <String>[for (final g in catalogue.shippedGlassFor(ownKey)) for (final p in g.pieces) p.stored],
            <String>[for (final g in catalogue.shippedGlassFor(baseKey)) for (final p in g.pieces) p.stored],
          );

          compared++;
          }
        }
        expect(compared, greaterThan(0));

        // Measured side by side, the frame still gets its own sides.
        expect(
          catalogue.frameSectionsFor('$context/${variant.code}'),
          <String>{
            for (final String section in catalogue.frameSectionsFor(
              '$context/${FormulaWindowKey.engineWindowFor(variant.baseCode, context)!.window}',
            ))
              variant.sectionFor(section),
          },
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
      final bool corner = variant.baseCode.contains('SC');
      for (final ({bool fabrication, int collar}) run in <({bool fabrication, int collar})>[
        for (final bool fabrication in <bool>[false, true])
          for (final int collar in <int>[if (variant.collars == null) 1, 2])
            (fabrication: fabrication, collar: collar),
      ]) {
        final bool fabrication = run.fabrication;
        final int collar = run.collar;
        test('${variant.code} ${fabrication ? 'fabrication' : 'estimation'} collar $collar: '
            'the base\'s sizes on its own profiles', () {
          WindowCutList cut(String code) => WindowCutCalculator(book).compute(
            WindowCutRequest(
              isFabrication: fabrication,
              appWindowCode: code,
              collarIndex: collar,
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
          // The same pieces, the same sizes. Their order follows the profiles'
          // names, which the swap changes; the engine piles them by profile.
          expect(
            <String>[for (final p in own.pieces) '${p.section} ${p.label} ${p.lengthFt}'],
            unorderedEquals(<String>[
              for (final p in base.pieces)
                '${variant.sectionFor(p.section)} ${p.label} ${p.lengthFt}',
            ]),
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

    test('B and BA: collar 2 only, drawn as the base\'s collar 2', () {
      for (final WindowVariant variant in bAndBa) {
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

    test('Economy: every collar of its base', () {
      for (final WindowVariant variant in economy) {
        final CollarLayout own = CollarLayout.forWindow(variant.code)!;
        final CollarLayout base = CollarLayout.forWindow(variant.baseCode)!;
        expect(own.collars, base.collars);
        expect(own.isWholeFrame, base.isWholeFrame);
        expect(own.toggle(1, CollarSide.top), base.toggle(1, CollarSide.top));
      }
    });

    test('ET24 or ET24A: one handler for the pair, switched in the sidebar', () {
      final WindowInputHandler handler = handlerForWindowCode('MPS4E_win');
      expect(handler, isA<VariantInputHandler>());
      final VariantInputHandler pair = handler as VariantInputHandler;
      expect(pair.alternateOn, isFalse);
      expect(pair.sectionsForCollar(1), contains('ET24'));
      expect(pair.sectionsForCollar(1), isNot(contains('M24')));
      pair.alternateOn = true;
      expect(pair.current.code, 'MPS4EA_win');
      expect(pair.sectionsForCollar(1), contains('ET24A'));
      expect(pair.sectionsForCollar(1), isNot(contains('ET24')));
      // The drawing still lights the M24 place for either.
      expect((pair.overlayForCollar(1, 'ET24A')! as dynamic).selectedSection, 'M24');

      // A window saved switched opens switched.
      final VariantInputHandler saved =
          handlerForWindowCode('MPS4EA_win') as VariantInputHandler;
      expect(saved.variant.code, 'MPS4E_win');
      expect(saved.alternateOn, isTrue);
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
