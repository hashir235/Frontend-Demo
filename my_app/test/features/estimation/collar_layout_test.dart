import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/window_catalog.dart';
import 'package:my_app/features/estimation/models/collar_layout.dart';
import 'package:my_app/features/estimation/models/window_variant.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_handler.dart';
import 'package:my_app/features/formulas/model/formula_window_key.dart';

/// The collar tables are the engine's: every side a collar type collars must
/// be cut from the collar profile, in both flows, for every window. A table
/// that drifted from the catalogue would draw one collar and cut another.
void main() {
  final Map<String, dynamic> catalogue =
      jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
          as Map<String, dynamic>;
  final Map<String, dynamic> windows = catalogue['windows'] as Map<String, dynamic>;

  List<String> leafCodes(List<WindowType> nodes) => <String>[
    for (final WindowType node in nodes)
      if (node.children.isEmpty) node.codeName! else ...leafCodes(node.children),
  ];
  final List<String> codes = leafCodes(WindowCatalog.root);

  const Map<String, CollarSide> sideOfLabel = <String, CollarSide>{
    'WT': CollarSide.top,
    'WB': CollarSide.bottom,
    'HL': CollarSide.left,
    'HR': CollarSide.right,
  };

  /// The engine's frame profiles for one window: those that change from one
  /// collar to another with everything else the same.
  Set<String> frameSections(Map<String, dynamic> configs) {
    final Map<String, Map<String, Map<String, dynamic>>> byRest =
        <String, Map<String, Map<String, dynamic>>>{};
    configs.forEach((String key, dynamic sections) {
      final List<String> parts = key.split('|');
      final String collar = parts.firstWhere((String p) => p.startsWith('collarType='));
      final String rest = parts.where((String p) => !p.startsWith('collarType=')).join('|');
      (byRest[rest] ??= <String, Map<String, dynamic>>{})[collar] =
          sections as Map<String, dynamic>;
    });
    final Set<String> frame = <String>{};
    for (final Map<String, Map<String, dynamic>> byCollar in byRest.values) {
      if (byCollar.length < 2) continue;
      final Set<String> all = <String>{for (final m in byCollar.values) ...m.keys};
      for (final String section in all) {
        final Set<String> shapes = <String>{
          for (final m in byCollar.values) jsonEncode(m[section]),
        };
        if (shapes.length > 1) frame.add(section);
      }
    }
    return frame;
  }

  int checked = 0;
  // Variant windows (the Prime and Royal lines) are their base's layout,
  // narrowed to their collars; window_variant_test holds them to that.
  for (final String code in codes.where((String c) => WindowVariants.of(c) == null)) {
    test('$code: the collar table is the engine\'s', () {
      final CollarLayout? layout = CollarLayout.forWindow(code);
      expect(layout, isNotNull, reason: 'every window on the menu has a layout');

      final WindowInputHandler handler = handlerForWindow(
        WindowType(
          label: code,
          graphicKey: '',
          children: const <WindowType>[],
          displayIndex: 1,
          codeName: code,
        ),
      );
      expect(layout!.collarCount, handler.collarCount,
          reason: 'as many collars as the screen has drawings for');

      for (final String context in <String>['fabrication', 'estimation']) {
        final FormulaWindowKey? bare = FormulaWindowKey.of(
          context: context,
          appWindowCode: code,
          dimensions: const <String>{},
          collarIndex: 1,
        );
        if (bare == null) continue;
        final Map<String, dynamic>? entry =
            windows[bare.windowKey] as Map<String, dynamic>?;
        if (entry == null) continue; // an arch has no fabrication formulas
        final Map<String, dynamic> configs = entry['configs'] as Map<String, dynamic>;
        final Set<String> frame = frameSections(configs);
        final Set<String> dimensions = <String>{
          for (final String part in configs.keys.first.split('|')) part.split('=').first,
        };

        for (int collar = 1; collar <= layout.collarCount; collar++) {
          // Any lock that exists for this window will do: the collar is what
          // decides the frame.
          Map<String, dynamic>? sections;
          for (final int lock in <int>[1, 2, 3]) {
            final FormulaWindowKey? key = FormulaWindowKey.of(
              context: context,
              appWindowCode: code,
              dimensions: dimensions,
              collarIndex: collar,
              lockType: lock,
              rubberType: 'F',
            );
            sections = key == null ? null : configs[key.configKey] as Map<String, dynamic>?;
            if (sections != null) break;
          }
          expect(sections, isNotNull, reason: '$context collar $collar exists');

          // A side is collared when every frame piece on it is a collar
          // profile (its name ends in F).
          final Map<String, Set<String>> profilesBySide = <String, Set<String>>{};
          sections!.forEach((String section, dynamic pieces) {
            if (!frame.contains(section)) return;
            for (final dynamic piece in pieces as List<dynamic>) {
              (profilesBySide[(piece as List<dynamic>)[0] as String] ??= <String>{}).add(section);
            }
          });
          final Map<String, bool> collared = profilesBySide.map(
            (String side, Set<String> profiles) =>
                MapEntry<String, bool>(side, profiles.every((String p) => p.endsWith('F'))),
          );

          if (layout.isWholeFrame) {
            // All round, or none. "All round" is every side but the bottom of
            // the round arch, which is never collared -- as on its drawing.
            if (collar == 2) {
              expect(collared.values.every((bool c) => !c), isTrue,
                  reason: '$context collar 2: $collared');
            } else {
              expect(
                collared.entries
                    .where((MapEntry<String, bool> e) => !e.value)
                    .every((MapEntry<String, bool> e) => code == 'A_win' && e.key == 'WB'),
                isTrue,
                reason: '$context collar 1: $collared',
              );
              expect(collared.values.any((bool c) => c), isTrue);
            }
          } else {
            final Set<CollarSide> engineSides = <CollarSide>{
              for (final MapEntry<String, bool> e in collared.entries)
                if (e.value && sideOfLabel.containsKey(e.key)) sideOfLabel[e.key]!,
            };
            expect(engineSides, layout.sidesWithCollar(collar),
                reason: '$context collar $collar: $collared');
          }
          checked++;
        }
      }
    });
  }

  test('every collar table was checked against the catalogue', () {
    expect(checked, greaterThan(300));
  });

  group('tapping a side', () {
    final CollarLayout four = CollarLayout.forWindow('S_win')!;

    test('takes that side\'s collar off, and a second tap puts it back', () {
      expect(four.toggle(1, CollarSide.top), 3);
      expect(four.toggle(3, CollarSide.top), 1);
      expect(four.toggle(1, CollarSide.bottom), 5);
      expect(four.toggle(5, CollarSide.right), 8, reason: 'top and left left');
      expect(four.toggle(8, CollarSide.right), 5);
    });

    test('a combination the engine does not have is refused', () {
      // Collar 6 is top, bottom and right; taking the bottom off would leave
      // top and right only -- there is no such collar.
      expect(four.toggle(6, CollarSide.bottom), isNull);
      // Collar 3 is bottom, left, right; taking the right off leaves bottom
      // and left only.
      expect(four.toggle(3, CollarSide.right), isNull);
    });

    test('every collar can be reached from collar 1 by taps', () {
      for (final String code in <String>['S_win', 'Single_Door', 'AR_win']) {
        final CollarLayout layout = CollarLayout.forWindow(code)!;
        final Set<int> reached = <int>{1};
        final List<int> queue = <int>[1];
        while (queue.isNotEmpty) {
          final int at = queue.removeLast();
          for (final CollarSide side in layout.sides) {
            final int? next = layout.toggle(at, side);
            if (next != null && reached.add(next)) queue.add(next);
          }
        }
        expect(reached.length, layout.collarCount, reason: code);
      }
    });

    test('a door has no bottom to tap', () {
      final CollarLayout door = CollarLayout.forWindow('Single_Door')!;
      expect(door.toggle(1, CollarSide.bottom), isNull);
      expect(door.toggle(1, CollarSide.right), 5);
    });

    test('the rectangle arch numbers its collars its own way', () {
      final CollarLayout arch = CollarLayout.forWindow('AR_win')!;
      final CollarLayout door = CollarLayout.forWindow('Single_Door')!;
      expect(arch.sidesWithCollar(6), <CollarSide>{CollarSide.top});
      expect(door.sidesWithCollar(6), <CollarSide>{CollarSide.right});
    });

    test('a whole-frame window switches all round, or not at all', () {
      final CollarLayout corner = CollarLayout.forWindow('SCF_win')!;
      expect(corner.isWholeFrame, isTrue);
      expect(corner.toggleWholeFrame(1), 2);
      expect(corner.toggleWholeFrame(2), 1);
      expect(corner.toggle(1, CollarSide.top), isNull);
    });
  });
}
