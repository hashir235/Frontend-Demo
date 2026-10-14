/// Windows that are another window with a different frame.
///
/// A window cut from the B/E frame is a sliding window in every way but one:
/// where the F/C window's frame is DC30F/DC30C and DC26F/DC26C, this one's is
/// DC30E/DC30B and DC26E/DC26B. Same drawing, same collars, same inner
/// profiles, the same formulas -- the ones the F/C profiles are cut by -- and
/// the same glass. So it is not written out again anywhere. It is described
/// here once, as its base window and what it changes, and everything else
/// asks.
///
/// Built to grow. The collars a variant comes in and the profiles it swaps
/// are data, not code: when a variant turns out to come in more collars, its
/// [WindowVariant.collars] gets longer (and [WindowVariant.sections] learns
/// what those collars' profiles become); a new frame is one more list.
library;

/// One window that is [baseCode] with some profiles swapped.
class WindowVariant {
  const WindowVariant({
    required this.code,
    required this.baseCode,
    required this.frame,
    required this.collars,
    required this.sections,
    this.alternateCode,
    this.isAlternate = false,
    this.own,
  });

  /// Set for a window that is its base's only on the outside -- the engine
  /// it is handed to, the screen it is entered on -- and cut to formulas of
  /// its own, from profiles of its own. Null for every frame variant above,
  /// which are their base's formulas under other names.
  final OwnWindow? own;

  /// This window's own code, as it is saved: "SB_win".
  final String code;

  /// The window it is made like: "S_win". Its drawing, its inputs and its
  /// formulas are this window's.
  final String baseCode;

  /// The frame it is on, by its profiles' letters: "B", "BA".
  final String frame;

  /// The collar types it comes in, numbered as [baseCode] numbers them;
  /// null for every collar its base comes in.
  ///
  /// The BA frame comes without a collar on any side -- collar 2 -- as far as
  /// is known today. Whether it comes in others is not confirmed, so only
  /// that one is offered; a formula for a collar nobody has checked would cut
  /// a frame nobody asked for. The B/E frame and the Economy windows come in
  /// all of their base's.
  final List<int>? collars;

  /// Whether this window comes in collar [collar].
  bool offersCollar(int collar) => collars?.contains(collar) ?? true;

  /// The same window with one profile swapped for another, which the
  /// fabricator chooses in the sidebar: the M-section Economy windows take
  /// their M24 place as ET24, or as ET24A. The two are saved as two codes,
  /// so the choice travels with the window like any other part of it.
  final String? alternateCode;

  /// True for the second of such a pair: it has no card of its own in the
  /// library, and is reached by switching its [alternateCode] over.
  final bool isAlternate;

  /// The profiles that differ from [baseCode]'s: its name for one, and this
  /// window's. Anything not named here is the same profile in both.
  ///
  /// A frame that comes only without a collar (BA) maps only the plain
  /// profiles (C), deliberately: it is never cut from the collar (F) ones. A
  /// collar added to [collars] later brings F profiles with it, and those
  /// need their own names here first -- as the B/E frame's E profiles are.
  final Map<String, String> sections;

  /// This window's name for [baseSection].
  String sectionFor(String baseSection) => sections[baseSection] ?? baseSection;

  /// The base window's name for this window's [section] -- what its drawing
  /// and its formulas know it as.
  String baseSectionFor(String section) {
    for (final MapEntry<String, String> entry in sections.entries) {
      if (entry.value == section) return entry.key;
    }
    return section;
  }
}

/// One piece of a window cut to formulas of its own: what the cutting list
/// calls it, and the sum that cuts it, written as the catalogue writes one.
typedef OwnPiece = ({String label, String formula});

/// One pane of glass a window cut to formulas of its own takes in
/// fabrication: its height and its width, in centimetres, written as the
/// catalogue writes a pane ("h - 14.2").
typedef OwnPane = ({String height, String width});

/// What a window cut to formulas of its own does its own way.
///
/// The first was the Prime Economy sliding window (Hashir, Oct 2026): a plain
/// two-panel sliding window on Prime's EF profiles, with no collar. The DELUXE
/// sliding window is the second, built the same way. To the engine each is
/// the sliding window at collar 2, which works out its area and names its
/// cuts; every length is the app's, from the formulas here, and so is every
/// pane of glass. A window whose glass formula is still to come (Prime
/// Economy) lists none, and none is cut.
class OwnWindow {
  const OwnWindow({
    required this.sections,
    required this.frame,
    required this.estimation,
    required this.fabrication,
    required this.gauges,
    required this.topRails,
    required this.bottomRails,
    required this.outerStiles,
    this.glass = const <OwnPane>[],
    this.colorNames = const <String, String>{},
    this.netSection,
  });

  /// The profiles of its panels' top rails, bottom rails and outer stiles
  /// (one at the left of the window, one at the right). A window measured
  /// side by side with a side more than 2 suter from the one facing it cuts
  /// each of these to its own side; its own names give no other way to tell.
  final String topRails;
  final String bottomRails;
  final String outerStiles;

  /// Its panes of glass in fabrication, in cutting order; empty while its
  /// glass formula is still to come.
  final List<OwnPane> glass;

  /// Its profiles, in the order the sidebar lists them.
  final List<String> sections;

  /// The profiles of its frame: on a window measured side by side, the ones
  /// cut to their own side.
  final Set<String> frame;

  /// Each profile's pieces in cutting order. Estimation's are in feet, with
  /// a margin per profile (`cm_...`); fabrication's in centimetres, as
  /// `(core + cm) / feet`, the way the catalogue writes every formula.
  final Map<String, List<OwnPiece>> estimation;
  final Map<String, List<OwnPiece>> fabrication;

  Map<String, List<OwnPiece>> formulasFor(String context) =>
      context == 'fabrication' ? fabrication : estimation;

  /// The one profile cut only when it is switched on in the sidebar, kept
  /// on the window as its addNet; null when every profile is always cut.
  final String? netSection;

  /// The gauges it comes in, written as the rate list writes them.
  final List<String> gauges;

  /// The finishes under its maker's names, keyed by the rate-list column
  /// each is priced from -- which is the colour's own value everywhere.
  /// Empty for a window that goes by the usual names (DELUXE).
  final Map<String, String> colorNames;

  /// Whether its finishes go by its maker's names rather than the usual ones.
  bool get hasOwnColorNames => colorNames.isNotEmpty;

  /// [color] as this maker names it.
  String colorNameFor(String color) => colorNames[color] ?? color;
}

/// Every variant window the app knows.
class WindowVariants {
  const WindowVariants._();

  // Fabrication sizes in suter, as Hashir gave them, in the centimetres the
  // formulas work in: eight suter to the inch, 2.54cm to the inch.
  //   3 suter            = 3/8"  = 0.9525cm
  //   7 suter            = 7/8"  = 2.2225cm
  //   3 inch 2 suter     = 3.25" = 8.255cm

  /// The Prime Economy sliding window: two panels, Prime's EF profiles.
  ///
  /// Estimation cuts it the way it cuts the plain sliding window with no
  /// collar -- heights to the height, the frame head and sill to the width,
  /// each panel's rails and the net to half of it -- and each piece takes the
  /// margin of the profile in the same place on that window, as the Economy
  /// windows do: one margin for a frame head, whoever makes it.
  ///
  /// Fabrication is Hashir's own list (Oct 2026): EF30 as measured; EF27 and
  /// EF26A 3 suter short of the width; EF22 and EF28 7 suter short of the
  /// height; EF25 and EF24 half of the width less 3 inch 2 suter; D29 the
  /// same as those, height and half-width.
  static const OwnWindow _primeEconomy = OwnWindow(
    sections: <String>['EF30', 'EF27', 'EF26A', 'EF25', 'EF24', 'EF22', 'EF28', 'D29'],
    frame: <String>{'EF30', 'EF27', 'EF26A'},
    topRails: 'EF25',
    bottomRails: 'EF24',
    outerStiles: 'EF22',
    netSection: 'D29',
    gauges: <String>['0.9mm'],
    colorNames: <String, String>{
      'DULL': 'Dull Silver',
      'H23/PC-RAL': 'Chm/Ral Gold',
      'SAHARA/ BROWN': 'Brown Sahara',
      'BLACK/ MULTI': 'Multi/BLK Ral +',
      'WOOD COAT': 'Wood Sahara +',
      // Priced as champagne, named as on every other window.
      'MILKY WHITE': 'Milky White',
      'BLACK MATTE': 'Black Matte',
    },
    estimation: <String, List<OwnPiece>>{
      // The frame: both jambs, the head, the sill.
      'EF30': <OwnPiece>[
        (label: 'HL', formula: 'h + cm_DC30C'),
        (label: 'HR', formula: 'h + cm_DC30C'),
      ],
      'EF27': <OwnPiece>[(label: 'WT', formula: 'w + cm_DC30C')],
      'EF26A': <OwnPiece>[(label: 'WB', formula: 'w + cm_DC26C')],
      // Each panel's top rail, then each one's bottom rail.
      'EF25': <OwnPiece>[
        (label: 'W1', formula: 'w / 2 + cm_M24'),
        (label: 'W2', formula: 'w / 2 + cm_M24'),
      ],
      'EF24': <OwnPiece>[
        (label: 'W3', formula: 'w / 2 + cm_M24'),
        (label: 'W4', formula: 'w / 2 + cm_M24'),
      ],
      // The outer stiles, left and right; the two meeting at the centre.
      'EF22': <OwnPiece>[
        (label: 'H', formula: 'h + cm_M23'),
        (label: 'H', formula: 'h + cm_M23'),
      ],
      'EF28': <OwnPiece>[
        (label: 'H', formula: 'h + cm_M28'),
        (label: 'H', formula: 'h + cm_M28'),
      ],
      // The net over one panel: two heights and two half-widths.
      'D29': <OwnPiece>[
        (label: 'HL', formula: 'h + cm_D29'),
        (label: 'HR', formula: 'h + cm_D29'),
        (label: 'WT', formula: 'w / 2 + cm_D29'),
        (label: 'WB', formula: 'w / 2 + cm_D29'),
      ],
    },
    fabrication: <String, List<OwnPiece>>{
      'EF30': <OwnPiece>[
        (label: 'HL', formula: '(h + cm) / feet'),
        (label: 'HR', formula: '(h + cm) / feet'),
      ],
      'EF27': <OwnPiece>[(label: 'WT', formula: '(w - 0.9525 + cm) / feet')],
      'EF26A': <OwnPiece>[(label: 'WB', formula: '(w - 0.9525 + cm) / feet')],
      'EF25': <OwnPiece>[
        (label: 'W1', formula: '((w - 8.255) / 2 + cm) / feet'),
        (label: 'W2', formula: '((w - 8.255) / 2 + cm) / feet'),
      ],
      'EF24': <OwnPiece>[
        (label: 'W3', formula: '((w - 8.255) / 2 + cm) / feet'),
        (label: 'W4', formula: '((w - 8.255) / 2 + cm) / feet'),
      ],
      'EF22': <OwnPiece>[
        (label: 'H', formula: '(h - 2.2225 + cm) / feet'),
        (label: 'H', formula: '(h - 2.2225 + cm) / feet'),
      ],
      'EF28': <OwnPiece>[
        (label: 'H', formula: '(h - 2.2225 + cm) / feet'),
        (label: 'H', formula: '(h - 2.2225 + cm) / feet'),
      ],
      'D29': <OwnPiece>[
        (label: 'HL', formula: '(h - 2.2225 + cm) / feet'),
        (label: 'HR', formula: '(h - 2.2225 + cm) / feet'),
        (label: 'WT', formula: '((w - 8.255) / 2 + cm) / feet'),
        (label: 'WB', formula: '((w - 8.255) / 2 + cm) / feet'),
      ],
    },
  );

  /// The Prime Economy line. One window so far: the two-panel sliding one.
  static const List<WindowVariant> _primeEconomyLine = <WindowVariant>[
    WindowVariant(
      code: 'SPE_win',
      baseCode: 'S_win',
      frame: 'PE',
      // No collar: the engine's collar 2, which is its sliding window with
      // none on any side. The screen offers no other.
      collars: <int>[2],
      sections: <String, String>{},
      own: _primeEconomy,
    ),
  ];

  // DELUXE's sizes in suter, in centimetres:
  //   2 suter            = 1/4"  = 0.635cm
  //   4 suter            = 1/2"  = 1.27cm
  //   1 inch             = 1"    = 2.54cm
  //   1 inch 4 suter     = 1.5"  = 3.81cm
  //   4 inch 2 suter     = 4.25" = 10.795cm
  //   5 inch 6 suter     = 5.75" = 14.605cm

  /// The DELUXE sliding window (Hashir, Oct 2026): two panels, no collar,
  /// 0.9mm only -- and only this one design, no three-panel or corner.
  ///
  /// Its frame is three profiles: D30 at the sides, D27 the head, D26A the
  /// sill. Inside, M23 is each panel's outer stile and M28 the two meeting
  /// at the centre, D25 the top rails and M24 the bottom ones, and D29 the
  /// net. M23, M24, M28 and D29 are the profiles every sliding window uses,
  /// priced from the same rows (Hashir).
  ///
  /// Estimation cuts it as the Prime Economy window is cut, and as the plain
  /// sliding window with no collar: heights to the height, head and sill to
  /// the width, rails and net to half of it, each with the margin of the
  /// profile in the same place on that window.
  ///
  /// Fabrication is Hashir's final sizes: D30 as measured; D27 and D26A 4
  /// suter short of the width; M23 and M28 1 inch short of the height; D25
  /// and M24 half of the width less 5 inch 6 suter; D29 1 inch 4 suter short
  /// of the height, and half the width as it is.
  ///
  /// Two panes of glass, one per panel (Hashir): 4 inch 2 suter short of the
  /// height, and half of the width less 5 inch 6 suter, with 2 suter added.
  static const OwnWindow _deluxe = OwnWindow(
    sections: <String>['D30', 'D27', 'D26A', 'M23', 'M28', 'D25', 'M24', 'D29'],
    frame: <String>{'D30', 'D27', 'D26A'},
    topRails: 'D25',
    bottomRails: 'M24',
    outerStiles: 'M23',
    netSection: 'D29',
    gauges: <String>['0.9mm'],
    glass: <OwnPane>[
      (height: 'h - 10.795', width: '(w - 14.605) / 2 + 0.635'),
      (height: 'h - 10.795', width: '(w - 14.605) / 2 + 0.635'),
    ],
    estimation: <String, List<OwnPiece>>{
      // The frame: both jambs, the head, the sill.
      'D30': <OwnPiece>[
        (label: 'HL', formula: 'h + cm_DC30C'),
        (label: 'HR', formula: 'h + cm_DC30C'),
      ],
      'D27': <OwnPiece>[(label: 'WT', formula: 'w + cm_DC30C')],
      'D26A': <OwnPiece>[(label: 'WB', formula: 'w + cm_DC26C')],
      // The outer stiles, left and right; the two meeting at the centre.
      'M23': <OwnPiece>[
        (label: 'H', formula: 'h + cm_M23'),
        (label: 'H', formula: 'h + cm_M23'),
      ],
      'M28': <OwnPiece>[
        (label: 'H', formula: 'h + cm_M28'),
        (label: 'H', formula: 'h + cm_M28'),
      ],
      // Each panel's top rail, then each one's bottom rail.
      'D25': <OwnPiece>[
        (label: 'W1', formula: 'w / 2 + cm_M24'),
        (label: 'W2', formula: 'w / 2 + cm_M24'),
      ],
      'M24': <OwnPiece>[
        (label: 'W3', formula: 'w / 2 + cm_M24'),
        (label: 'W4', formula: 'w / 2 + cm_M24'),
      ],
      // The net over one panel: two heights and two half-widths.
      'D29': <OwnPiece>[
        (label: 'HL', formula: 'h + cm_D29'),
        (label: 'HR', formula: 'h + cm_D29'),
        (label: 'WT', formula: 'w / 2 + cm_D29'),
        (label: 'WB', formula: 'w / 2 + cm_D29'),
      ],
    },
    fabrication: <String, List<OwnPiece>>{
      'D30': <OwnPiece>[
        (label: 'HL', formula: '(h + cm) / feet'),
        (label: 'HR', formula: '(h + cm) / feet'),
      ],
      'D27': <OwnPiece>[(label: 'WT', formula: '(w - 1.27 + cm) / feet')],
      'D26A': <OwnPiece>[(label: 'WB', formula: '(w - 1.27 + cm) / feet')],
      'M23': <OwnPiece>[
        (label: 'H', formula: '(h - 2.54 + cm) / feet'),
        (label: 'H', formula: '(h - 2.54 + cm) / feet'),
      ],
      'M28': <OwnPiece>[
        (label: 'H', formula: '(h - 2.54 + cm) / feet'),
        (label: 'H', formula: '(h - 2.54 + cm) / feet'),
      ],
      'D25': <OwnPiece>[
        (label: 'W1', formula: '((w - 14.605) / 2 + cm) / feet'),
        (label: 'W2', formula: '((w - 14.605) / 2 + cm) / feet'),
      ],
      'M24': <OwnPiece>[
        (label: 'W3', formula: '((w - 14.605) / 2 + cm) / feet'),
        (label: 'W4', formula: '((w - 14.605) / 2 + cm) / feet'),
      ],
      'D29': <OwnPiece>[
        (label: 'HL', formula: '(h - 3.81 + cm) / feet'),
        (label: 'HR', formula: '(h - 3.81 + cm) / feet'),
        (label: 'WT', formula: '(w / 2 + cm) / feet'),
        (label: 'WB', formula: '(w / 2 + cm) / feet'),
      ],
    },
  );

  /// The DELUXE line: the two-panel sliding window, and nothing else.
  static const List<WindowVariant> _deluxeLine = <WindowVariant>[
    WindowVariant(
      code: 'SDX_win',
      baseCode: 'S_win',
      frame: 'DX',
      // No collar, as the Prime Economy window: the engine's collar 2.
      collars: <int>[2],
      sections: <String, String>{},
      own: _deluxe,
    ),
  ];

  static const List<int> _noCollar = <int>[2];

  /// The Economy frame and profiles, on the plain sliding windows.
  static const Map<String, String> _economy = <String, String>{
    'DC30F': 'EC30F',
    'DC26F': 'EC26F',
    'DC30C': 'EC30B',
    'DC26C': 'EC26B',
    'M23': 'EC23',
    'M24': 'EC24',
    'M28': 'EC28',
  };

  /// And on the M-section ones: the ET profiles.
  static const Map<String, String> _economyM = <String, String>{
    'M30F': 'ET30',
    'M26F': 'ET26',
    'M30': 'ET30A',
    'M26': 'ET26A',
    'M23': 'ET23',
    'M24': 'ET24',
    'M28': 'ET28',
  };

  /// The M-section Economy windows with ET24A in the M24 place.
  static const Map<String, String> _economyMAlternate = <String, String>{
    'M30F': 'ET30',
    'M26F': 'ET26',
    'M30': 'ET30A',
    'M26': 'ET26A',
    'M23': 'ET23',
    'M24': 'ET24A',
    'M28': 'ET28',
  };

  /// The M-section sliding windows: the Economy line has them too.
  static const List<String> _slidingMBases = <String>[
    'MS_win',
    'MPF3_win',
    'MPS4_win',
    'MEF3_win',
    'MSCF_win',
    'MSCS_win',
    'MSCL_win',
    'MSCR_win',
  ];

  static String _codeOf(String base, String suffix) =>
      base.replaceFirst('_win', '${suffix}_win');

  static List<WindowVariant> _economyLine() => <WindowVariant>[
    for (final String base in _slidingBases)
      WindowVariant(
        code: _codeOf(base, 'E'),
        baseCode: base,
        frame: 'E',
        collars: null,
        sections: _economy,
      ),
    for (final String base in _slidingMBases) ...<WindowVariant>[
      WindowVariant(
        code: _codeOf(base, 'E'),
        baseCode: base,
        frame: 'E',
        collars: null,
        sections: _economyM,
        alternateCode: _codeOf(base, 'EA'),
      ),
      WindowVariant(
        code: _codeOf(base, 'EA'),
        baseCode: base,
        frame: 'E',
        collars: null,
        sections: _economyMAlternate,
        alternateCode: _codeOf(base, 'E'),
        isAlternate: true,
      ),
    ],
  ];

  /// The B/E frame, built the way the F/C frame is (Hashir, Oct 2026): E
  /// where a side has its collar, as F is, and B where it has none, as C is
  /// -- DC30E/DC30B at the top and sides, DC26E/DC26B at the bottom. Every
  /// collar the base comes in, each cut by the F/C profile's own formula.
  static const Map<String, String> _bFrame = <String, String>{
    'DC30F': 'DC30E',
    'DC26F': 'DC26E',
    'DC30C': 'DC30B',
    'DC26C': 'DC26B',
  };

  /// The BA frame: DC30BA and DC26BA.
  static const Map<String, String> _baFrame = <String, String>{
    'DC30C': 'DC30BA',
    'DC26C': 'DC26BA',
  };

  /// The sliding windows each frame comes in: the sliding window, the three
  /// panel windows and the four sliding corners. No M-section ones.
  static const List<String> _slidingBases = <String>[
    'S_win',
    'PF3_win',
    'PS4_win',
    'EF3_win',
    'SCF_win',
    'SCS_win',
    'SCL_win',
    'SCR_win',
  ];

  static List<WindowVariant> _frame(
    String suffix,
    Map<String, String> sections, {
    required List<int>? collars,
  }) =>
      <WindowVariant>[
        for (final String base in _slidingBases)
          WindowVariant(
            code: _codeOf(base, suffix),
            baseCode: base,
            frame: suffix,
            collars: collars,
            sections: sections,
          ),
      ];

  /// Every variant: the B/E frame, the BA frame, the Economy line, the Prime
  /// Economy one, then DELUXE.
  ///
  /// The B/E frame keeps the codes the B frame was saved under ("SB_win"), so
  /// every window already saved on it opens as it was.
  static final List<WindowVariant> all = List<WindowVariant>.unmodifiable(
    <WindowVariant>[
      ..._frame('B', _bFrame, collars: null),
      ..._frame('BA', _baFrame, collars: _noCollar),
      ..._economyLine(),
      ..._primeEconomyLine,
      ..._deluxeLine,
    ],
  );

  /// What window [code] does its own way, or null for every window cut to
  /// its own base's formulas (or a window that is no variant at all).
  static OwnWindow? ownOf(String? code) => of(code)?.own;

  static final Map<String, WindowVariant> _byCode = <String, WindowVariant>{
    for (final WindowVariant variant in all) variant.code: variant,
  };

  /// The variant saved as [code], or null for a window that is its own.
  static WindowVariant? of(String? code) =>
      code == null ? null : _byCode[code.trim()];

  /// The window [code] is made like: its base for a variant, itself otherwise.
  /// Whatever decides how a window behaves -- which input screen, which lock,
  /// which drawing -- asks this rather than the code as saved.
  static String baseCode(String code) => of(code)?.baseCode ?? code;

  /// The code [code]'s window has in the library: for the second of a
  /// switched pair (ET24A) the first's, for anything else itself.
  static String libraryCode(String code) {
    final WindowVariant? variant = of(code);
    return variant != null && variant.isAlternate ? variant.alternateCode! : code;
  }

  /// The profile a switched pair differs in, as each of the pair names it:
  /// (own: 'ET24', other: 'ET24A') for an M-section Economy window. Null for a
  /// window with no such choice.
  static ({String own, String other})? alternateProfile(String code) {
    final WindowVariant? variant = of(code);
    final WindowVariant? other = of(variant?.alternateCode);
    if (variant == null || other == null) return null;
    for (final MapEntry<String, String> entry in variant.sections.entries) {
      final String theirs = other.sectionFor(entry.key);
      if (theirs != entry.value) return (own: entry.value, other: theirs);
    }
    return null;
  }
}
