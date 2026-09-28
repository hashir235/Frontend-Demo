import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/window_catalog.dart';
import 'package:my_app/features/estimation/data/window_sections.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/models/window_variant.dart';
import 'package:my_app/features/formulas/model/formula_window_key.dart';

/// "Used Sections" in the library is the engine's word, not a description:
/// for every window, in each flow, exactly the sections the formula catalogue
/// cuts it from -- and a section that only comes with an option (the net, a
/// door's bottom or tee) is marked as such.
void main() {
  final Map<String, dynamic> windows =
      (jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
              as Map<String, dynamic>)['windows']
          as Map<String, dynamic>;

  List<WindowType> leaves(List<WindowType> nodes) => <WindowType>[
    for (final WindowType node in nodes)
      if (node.children.isEmpty) node else ...leaves(node.children),
  ];

  /// The catalogue configurations that are this window's, by asking the
  /// app's own window key to name each one back.
  Map<String, Map<String, dynamic>>? configsOf(String code, String context) {
    // A variant window is not in the catalogue file: it is its base window,
    // in the collars it comes in, with its own profiles' names -- the rule
    // WindowVariants states, applied here to the file directly.
    final WindowVariant? variant = WindowVariants.of(code);
    if (variant != null) {
      final Map<String, Map<String, dynamic>>? base = configsOf(variant.baseCode, context);
      if (base == null) return null;
      return <String, Map<String, dynamic>>{
        for (final MapEntry<String, Map<String, dynamic>> config in base.entries)
          if (variant.offersCollar(int.parse(
            config.key.split('|').firstWhere((String p) => p.startsWith('collarType=')).split('=')[1],
          )))
            config.key: <String, dynamic>{
              for (final MapEntry<String, dynamic> section in config.value.entries)
                variant.sectionFor(section.key): section.value,
            },
      };
    }
    final FormulaWindowKey? bare = FormulaWindowKey.of(
      context: context,
      appWindowCode: code,
      dimensions: const <String>{},
      collarIndex: 1,
    );
    final Map<String, dynamic>? entry = windows[bare!.windowKey] as Map<String, dynamic>?;
    if (entry == null) return null;
    final Map<String, Map<String, dynamic>> mine = <String, Map<String, dynamic>>{};
    (entry['configs'] as Map<String, dynamic>).forEach((String configKey, dynamic sections) {
      final Map<String, String> values = <String, String>{
        for (final String part in configKey.split('|')) part.split('=')[0]: part.split('=')[1],
      };
      final FormulaWindowKey? key = FormulaWindowKey.of(
        context: context,
        appWindowCode: code,
        dimensions: values.keys.toSet(),
        collarIndex: int.parse(values['collarType']!),
        lockType: values['lockType'] == null ? null : int.parse(values['lockType']!),
        rubberType: values['rubberType'],
        addBottom: values['addBottom'] == 'true',
        addTee: values['addTee'] == 'true',
        addNet: values['addNet'] == 'true',
        backCollarCm: double.tryParse(values['backCollarCm'] ?? '') ?? 1.7,
      );
      if (key?.configKey == configKey) {
        mine[configKey] = sections as Map<String, dynamic>;
      }
    });
    return mine;
  }

  for (final WindowType node in leaves(WindowCatalog.root)) {
    final String code = node.codeName!;
    for (final String context in <String>['estimation', 'fabrication']) {
      test('$code ($context): the sections are the engine\'s', () {
        final Map<String, Map<String, dynamic>>? configs = configsOf(code, context);
        if (configs == null) {
          // No formulas in this flow (the arches in fabrication) -- and then
          // the library must not offer the window there either.
          expect(context, 'fabrication');
          final List<String> offered = <String>[
            for (final WindowGroup group in WindowCatalog.groupsForFlow(isFabrication: true))
              for (final WindowType n in leaves(group.nodes)) n.codeName!,
          ];
          expect(offered, isNot(contains(code)));
          return;
        }
        expect(configs, isNotEmpty, reason: 'the window key finds its own configurations');

        final List<UsedSection> listed =
            WindowSections.of(code, isFabrication: context == 'fabrication');
        final Set<String> cut = <String>{
          for (final Map<String, dynamic> sections in configs.values) ...sections.keys,
        };
        expect(listed.map((UsedSection s) => s.code).toSet(), cut);
        expect(listed.length, cut.length, reason: 'no section listed twice');

        for (final UsedSection section in listed) {
          configs.forEach((String configKey, Map<String, dynamic> sections) {
            final bool present = sections.containsKey(section.code);
            if (section.option == null) return;
            // The app's own option, not the engine's: the app leaves D31 out
            // while it is switched off. (In fabrication the engine itself
            // cuts it with some locks only.)
            if (section.option == 'addD31') return;
            final bool optionOn = configKey.split('|').contains('${section.option}=true');
            expect(present, optionOn,
                reason: '${section.code} comes exactly with ${section.option}: $configKey');
          });
          if (section.option == 'addD31') {
            expect(
              configs.values.any((Map<String, dynamic> sections) =>
                  sections.containsKey(section.code)),
              isTrue,
              reason: 'D31 is cut somewhere, when switched on',
            );
          }
          if (section.option == null) {
            // "Always there" has to mean some configuration without any
            // option switched on still cuts it.
            expect(
              configs.entries.any((MapEntry<String, Map<String, dynamic>> e) =>
                  !e.key.contains('=true') && e.value.containsKey(section.code)),
              isTrue,
              reason: '${section.code} is not only an option\'s',
            );
          }
        }
      });
    }
  }

  test('frame sections come first, collar and plain side by side', () {
    expect(
      WindowSections.of('S_win', isFabrication: false).map((UsedSection s) => s.label),
      <String>['DC30F', 'DC30C', 'DC26F', 'DC26C', 'D29', 'M23', 'M24', 'M28'],
    );
    expect(
      WindowSections.of('MPS4_win', isFabrication: true).map((UsedSection s) => s.label),
      <String>['M30F', 'M30', 'M26F', 'M26', 'D31 (optional)', 'M23', 'M24', 'M28'],
    );
  });

  test('a section that comes with an option says so', () {
    expect(
      WindowSections.of('O_win', isFabrication: false).map((UsedSection s) => s.label),
      <String>['D54F', 'D54A', 'D50A', 'D29 (net)'],
    );
    expect(
      WindowSections.of('Single_Door', isFabrication: true).map((UsedSection s) => s.label),
      <String>['D54F', 'D54A', 'D50', 'D46 (optional)', 'D52 (optional)'],
    );
  });

  test('a family lists every section of the windows inside it', () {
    for (final bool fabrication in <bool>[false, true]) {
      for (final WindowGroup group in WindowCatalog.groupsForFlow(isFabrication: fabrication)) {
        for (final WindowType node in group.nodes.where((WindowType n) => n.hasChildren)) {
          final Set<String> expected = <String>{
            for (final WindowType child in leaves(node.children))
              for (final UsedSection s in WindowSections.of(child.codeName!, isFabrication: fabrication))
                s.code,
          };
          expect(
            WindowSections.forNode(node, isFabrication: fabrication)
                .map((UsedSection s) => s.code)
                .toSet(),
            expected,
            reason: node.label,
          );
        }
      }
    }
    final WindowType panels = WindowCatalog.root.firstWhere(
      (WindowType n) => n.label == 'Panel Windows',
    );
    expect(
      WindowSections.forNode(panels, isFabrication: false).map((UsedSection s) => s.code),
      contains('D31'),
      reason: 'the centre slide brings its D31 to the family',
    );
  });

  test('the library rows: sliding windows, then box type windows', () {
    final List<WindowGroup> estimation = WindowCatalog.groupsForFlow(isFabrication: false);
    expect(estimation.map((WindowGroup g) => g.title),
        <String>['Sliding Windows', 'Economy Sliding Window', 'Box type Windows']);
    expect(estimation[0].rows.map((WindowRow r) => r.id),
        <String>['sliding', 'sliding_b', 'sliding_ba']);
    expect(estimation[0].rows[0].nodes.map((WindowType n) => n.label), <String>[
      'Sliding Window',
      'Sliding Window M_Section',
      'Panel Windows',
      'Panel Windows M_Section',
      'Sliding Corner Windows',
      'Sliding Corner Windows M_Section',
    ]);
    expect(estimation[0].rows[1].nodes.map((WindowType n) => n.label),
        <String>['Prime Sliding Window', 'Prime Panel Windows', 'Prime Corner Windows']);
    expect(estimation[0].rows[2].nodes.map((WindowType n) => n.label),
        <String>['Royal Sliding Window', 'Royal Panel Windows', 'Royal Corner Windows']);
    expect(estimation[1].rows.single.nodes, WindowCatalog.economyWindows);
    expect(estimation[2].nodes.map((WindowType n) => n.label),
        <String>['Fix Window', 'Corner Fix', 'Openable', 'Door', 'Arch']);

    final List<WindowGroup> fabrication = WindowCatalog.groupsForFlow(isFabrication: true);
    expect(fabrication[0].nodes.length, 12);
    expect(fabrication[1].nodes.length, 6);
    expect(fabrication[2].nodes.map((WindowType n) => n.label),
        <String>['Fix Window', 'Corner Fix', 'Openable', 'Door']);

    // Nothing lost or doubled in the split.
    expect(
      <WindowType>[
        for (final WindowGroup group in estimation) ...group.nodes,
      ],
      WindowCatalog.root,
    );
  });
}
