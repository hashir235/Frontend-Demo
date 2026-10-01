part of 'window_input_handler.dart';

/// A variant window's input: its base window's, with its own profiles.
///
/// Everything a fabricator sees and does -- the size boxes, the split widths
/// of a corner, the collar drawing -- is the base window's. What changes is
/// the names of the profiles the variant swaps (DC30C becomes DC30B, say),
/// wherever a profile is listed, and which collars it offers. The drawing
/// itself only knows the base's names, so a profile picked in the sidebar is
/// handed to it under the base's name to light up the right part.
///
/// A window with a switchable profile (ET24 or ET24A) is one handler for the
/// pair: [alternateOn] says which of the two is in use, the way a door's
/// handler holds its D46 and D52 switches.
class VariantInputHandler extends WindowInputHandler {
  VariantInputHandler({required this.base, required this.variant});

  final WindowInputHandler base;

  /// The variant on the window's library card.
  final WindowVariant variant;

  /// Whether the other of a switchable pair is in use.
  bool alternateOn = false;

  /// The variant in use: [variant], or its pair when switched.
  WindowVariant get current =>
      alternateOn ? (WindowVariants.of(variant.alternateCode) ?? variant) : variant;

  /// For a window cut to formulas of its own: whether its switched profile
  /// (the net, D29) is cut. Off until switched on, like the openable's net.
  bool netEnabled = false;

  /// What this window does its own way, or null for a frame variant.
  OwnWindow? get own => variant.own;

  @override
  bool get usesSplitWidthInputs => base.usesSplitWidthInputs;

  @override
  bool get usesArchInput => base.usesArchInput;

  /// The base's count: collars keep the base's numbers, so the drawings do
  /// too. Which of them this window offers is the collar layout's business.
  @override
  int get collarCount => base.collarCount;

  @override
  Map<int, List<String>> get sectionsByCollar {
    final OwnWindow? mine = own;
    if (mine != null) {
      // Its own profiles at the one collar it comes in, the net only while
      // it is switched on.
      return <int, List<String>>{
        for (final int collar in variant.collars ?? const <int>[2])
          collar: <String>[
            for (final String section in mine.sections)
              if (section != mine.netSection || netEnabled) section,
          ],
      };
    }
    return _baseSectionsByCollar;
  }

  Map<int, List<String>> get _baseSectionsByCollar => <int, List<String>>{
    for (final MapEntry<int, List<String>> entry in base.sectionsByCollar.entries)
      if (variant.offersCollar(entry.key))
        entry.key: <String>[
          for (final String section in entry.value) current.sectionFor(section),
        ],
  };

  @override
  Map<int, Map<String, String>> get sectionAliasesByCollar {
    if (own != null) return const <int, Map<String, String>>{};
    return _baseSectionAliasesByCollar;
  }

  Map<int, Map<String, String>> get _baseSectionAliasesByCollar =>
      <int, Map<String, String>>{
    for (final MapEntry<int, Map<String, String>> entry
        in base.sectionAliasesByCollar.entries)
      if (variant.offersCollar(entry.key))
        entry.key: <String, String>{
          for (final MapEntry<String, String> alias in entry.value.entries)
            current.sectionFor(alias.key): current.sectionFor(alias.value),
        },
  };

  @override
  Widget? overlayForCollar(int collarIndex, String? selectedSection) {
    // Its own drawing, plain, under its own profiles' names. The Prime
    // Economy sliding window is the only window cut to formulas of its own.
    if (own != null) {
      return PrimeEconomySlidingOverlay(selectedSection: selectedSection);
    }
    return base.overlayForCollar(
      collarIndex,
      selectedSection == null ? null : current.baseSectionFor(selectedSection),
    );
  }
}
