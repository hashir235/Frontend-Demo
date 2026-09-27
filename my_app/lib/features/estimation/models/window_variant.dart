/// Windows that are another window with a different frame.
///
/// A window cut from the DC30B / DC26B frame is a sliding window in every way
/// but one: where the plain window's frame is DC30C and DC26C, this one's is
/// DC30B and DC26B. Same drawing, same inner profiles, the same formulas --
/// the ones DC30C and DC26C are cut by -- and the same glass. So it is not
/// written out again anywhere. It is described here once, as its base window
/// and what it changes, and everything else asks.
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
  });

  /// This window's own code, as it is saved: "SB_win".
  final String code;

  /// The window it is made like: "S_win". Its drawing, its inputs and its
  /// formulas are this window's.
  final String baseCode;

  /// The frame it is on, by its profiles' letters: "B", "BA".
  final String frame;

  /// The collar types it comes in, numbered as [baseCode] numbers them.
  ///
  /// The B and BA frames come without a collar on any side -- collar 2 --
  /// as far as is known today. Whether they come in others is not confirmed,
  /// so only that one is offered; a formula for a collar nobody has checked
  /// would cut a frame nobody asked for.
  final List<int> collars;

  /// The profiles that differ from [baseCode]'s: its name for one, and this
  /// window's. Anything not named here is the same profile in both.
  ///
  /// Only the plain frame (C) is mapped, deliberately: these frames are cut by
  /// the C profiles' formulas, never the collar (F) ones. A collar added to
  /// [collars] later brings F profiles with it, and those need their own
  /// names here first.
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

/// Every variant window the app knows.
class WindowVariants {
  const WindowVariants._();

  static const List<int> _noCollar = <int>[2];

  /// The B frame: DC30B at the top and sides, DC26B at the bottom.
  static const Map<String, String> _bFrame = <String, String>{
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

  static List<WindowVariant> _frame(String suffix, Map<String, String> sections) =>
      <WindowVariant>[
        for (final String base in _slidingBases)
          WindowVariant(
            code: base.replaceFirst('_win', '${suffix}_win'),
            baseCode: base,
            frame: suffix,
            collars: _noCollar,
            sections: sections,
          ),
      ];

  /// Every variant, B frame first.
  static final List<WindowVariant> all = List<WindowVariant>.unmodifiable(
    <WindowVariant>[..._frame('B', _bFrame), ..._frame('BA', _baFrame)],
  );

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
}
