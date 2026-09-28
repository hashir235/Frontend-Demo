import '../models/window_type.dart';
import '../models/window_variant.dart';

/// One section (profile) a window is cut from.
class UsedSection {
  const UsedSection(this.code, {this.option, this.orAs});

  /// The section's name, as it is written on the drawings: "DC30F", "D29".
  final String code;

  /// The setting that brings this section in, when it is not always there:
  /// `addNet`, `addBottom` or `addTee` (the engine's), or `addD31` (the app's
  /// own: D31 is cut only when switched on). Null when every window of this
  /// kind is cut from it.
  final String? option;

  /// The profile the fabricator can switch this one for in the sidebar --
  /// ET24A for ET24 on the M-section Economy windows.
  final String? orAs;

  /// How the library writes it: the name, and when it only comes with an
  /// option, which one; a switchable one with its other name.
  String get label {
    final String name = orAs == null ? code : '$code / $orAs';
    return switch (option) {
      null => name,
      'addNet' => '$name (net)',
      _ => '$name (optional)',
    };
  }
}

/// The sections each window is made of, as the library lists them under the
/// window's name.
///
/// These are the engine's: every section any collar, lock or rubber of the
/// window is cut from, in that flow. `window_sections_test.dart` holds this
/// table against the formula catalogue, so a window that gains or loses a
/// section in the engine fails there before the library says otherwise.
class WindowSections {
  const WindowSections._();

  /// The order sections are listed in, whichever window they come from: the
  /// frame first -- collar (F) and plain (C) side by side -- then the sash,
  /// the interlock and the rest.
  static const List<String> _order = <String>[
    'DC30F', 'DC30C', 'DC26F', 'DC26C',
    'DC30B', 'DC26B', 'DC30BA', 'DC26BA',
    'EC30F', 'EC30B', 'EC26F', 'EC26B',
    'M30F', 'M30', 'M26F', 'M26',
    'ET30', 'ET30A', 'ET26', 'ET26A',
    'D54F', 'D54A', 'D51F', 'D51A',
    'D50', 'D50A', 'D41', 'D29', 'D31',
    'M23', 'M24', 'M28',
    'EC23', 'EC24', 'EC28',
    'ET23', 'ET24', 'ET24A', 'ET28',
    'D46', 'D52',
  ];

  static const List<UsedSection> _sliding = <UsedSection>[
    UsedSection('DC30F'), UsedSection('DC30C'),
    UsedSection('DC26F'), UsedSection('DC26C'),
    UsedSection('D29'), UsedSection('M23'), UsedSection('M24'), UsedSection('M28'),
  ];

  /// The sliding windows on the B frame: the plain frame's inner profiles,
  /// with DC30B and DC26B for the frame. No collar, so no F profiles.
  static const List<UsedSection> _slidingB = <UsedSection>[
    UsedSection('DC30B'), UsedSection('DC26B'),
    UsedSection('D29'), UsedSection('M23'), UsedSection('M24'), UsedSection('M28'),
  ];

  /// And on the BA frame: DC30BA and DC26BA.
  static const List<UsedSection> _slidingBA = <UsedSection>[
    UsedSection('DC30BA'), UsedSection('DC26BA'),
    UsedSection('D29'), UsedSection('M23'), UsedSection('M24'), UsedSection('M28'),
  ];

  static const List<UsedSection> _slidingM = <UsedSection>[
    UsedSection('M30F'), UsedSection('M30'), UsedSection('M26F'), UsedSection('M26'),
    UsedSection('M23'), UsedSection('M24'), UsedSection('M28'),
  ];

  static const List<UsedSection> _fix = <UsedSection>[
    UsedSection('D54F'), UsedSection('D54A'), UsedSection('D41'),
  ];

  static const List<UsedSection> _door = <UsedSection>[
    UsedSection('D54F'), UsedSection('D54A'), UsedSection('D50'),
    UsedSection('D46', option: 'addBottom'), UsedSection('D52', option: 'addTee'),
  ];

  static const List<UsedSection> _arch = <UsedSection>[
    UsedSection('D51F'), UsedSection('D51A'), UsedSection('D41'),
  ];

  static const Map<String, List<UsedSection>> _estimation = <String, List<UsedSection>>{
    'S_win': _sliding,
    'MS_win': _slidingM,
    'PF3_win': _sliding,
    'PS4_win': <UsedSection>[..._sliding, UsedSection('D31', option: 'addD31')],
    'EF3_win': _sliding,
    'MPF3_win': _slidingM,
    'MPS4_win': <UsedSection>[..._slidingM, UsedSection('D31', option: 'addD31')],
    'MEF3_win': _slidingM,
    'SCF_win': _sliding,
    'SCS_win': _sliding,
    'SCL_win': _sliding,
    'SCR_win': _sliding,
    // The engine cuts a D29 in this one M-section corner window, and in
    // fabrication in the left-fix one instead -- listed as the engine has it.
    'MSCF_win': <UsedSection>[..._slidingM, UsedSection('D29')],
    'MSCS_win': _slidingM,
    'MSCL_win': _slidingM,
    'MSCR_win': _slidingM,
    'F_win': _fix,
    'FC_win': _fix,
    'O_win': <UsedSection>[
      UsedSection('D54F'), UsedSection('D54A'), UsedSection('D50A'),
      UsedSection('D29', option: 'addNet'),
    ],
    'Single_Door': _door,
    'Double_Door': _door,
    'A_win': _arch,
    'AR_win': _arch,
    'SB_win': _slidingB,
    'PF3B_win': _slidingB,
    'PS4B_win': <UsedSection>[..._slidingB, UsedSection('D31', option: 'addD31')],
    'EF3B_win': _slidingB,
    'SCFB_win': _slidingB,
    'SCSB_win': _slidingB,
    'SCLB_win': _slidingB,
    'SCRB_win': _slidingB,
    'SBA_win': _slidingBA,
    'PF3BA_win': _slidingBA,
    'PS4BA_win': <UsedSection>[..._slidingBA, UsedSection('D31', option: 'addD31')],
    'EF3BA_win': _slidingBA,
    'SCFBA_win': _slidingBA,
    'SCSBA_win': _slidingBA,
    'SCLBA_win': _slidingBA,
    'SCRBA_win': _slidingBA,
  };

  /// Where fabrication's sections differ from estimation's.
  static const Map<String, List<UsedSection>> _fabrication = <String, List<UsedSection>>{
    'MSCF_win': _slidingM,
    'MSCL_win': <UsedSection>[..._slidingM, UsedSection('D29')],
  };

  /// The sections window [code] is cut from, in list order; empty for a
  /// window this table does not know.
  static List<UsedSection> of(String code, {required bool isFabrication}) {
    final List<UsedSection>? listed =
        (isFabrication ? _fabrication[code] : null) ?? _estimation[code];
    if (listed != null) return _sorted(listed);

    // A variant in every collar its base comes in is its base's list under
    // its own names, in its base's order.
    final WindowVariant? variant = WindowVariants.of(code);
    if (variant != null && variant.collars == null) {
      final ({String own, String other})? switchable =
          WindowVariants.alternateProfile(code);
      return List<UsedSection>.unmodifiable(<UsedSection>[
        for (final UsedSection base in of(variant.baseCode, isFabrication: isFabrication))
          UsedSection(
            variant.sectionFor(base.code),
            option: base.option,
            orAs: switchable != null && variant.sectionFor(base.code) == switchable.own
                ? switchable.other
                : null,
          ),
      ]);
    }
    return const <UsedSection>[];
  }

  /// The sections of [node]: its own for a window, and every section of the
  /// windows inside it for a family.
  static List<UsedSection> forNode(WindowType node, {required bool isFabrication}) {
    if (!node.hasChildren) {
      return of(node.codeName ?? '', isFabrication: isFabrication);
    }
    final Map<String, UsedSection> byCode = <String, UsedSection>{};
    void walk(WindowType n) {
      if (n.hasChildren) {
        n.children.forEach(walk);
        return;
      }
      for (final UsedSection section in of(n.codeName ?? '', isFabrication: isFabrication)) {
        final UsedSection? seen = byCode[section.code];
        // Always there in one window beats "only with an option" in another.
        if (seen == null || (seen.option != null && section.option == null)) {
          byCode[section.code] = section;
        }
      }
    }

    walk(node);
    return _sorted(byCode.values.toList());
  }

  /// [sections] in list order. Anything the order does not name goes last,
  /// in the order it came.
  static List<UsedSection> _sorted(List<UsedSection> sections) {
    int rank(int i) {
      final int at = _order.indexOf(sections[i].code);
      return at < 0 ? _order.length : at;
    }

    final List<int> positions = List<int>.generate(sections.length, (int i) => i)
      ..sort((int a, int b) {
        final int byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : a.compareTo(b);
      });
    return List<UsedSection>.unmodifiable(<UsedSection>[
      for (final int i in positions) sections[i],
    ]);
  }
}
