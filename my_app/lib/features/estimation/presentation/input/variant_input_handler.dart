part of 'window_input_handler.dart';

/// A variant window's input: its base window's, with its own profiles.
///
/// Everything a fabricator sees and does -- the size boxes, the split widths
/// of a corner, the collar drawing -- is the base window's. What changes is
/// the names of the profiles the variant swaps (DC30C becomes DC30B, say),
/// wherever a profile is listed, and which collars it offers. The drawing
/// itself only knows the base's names, so a profile picked in the sidebar is
/// handed to it under the base's name to light up the right part.
class VariantInputHandler extends WindowInputHandler {
  const VariantInputHandler({required this.base, required this.variant});

  final WindowInputHandler base;
  final WindowVariant variant;

  @override
  bool get usesSplitWidthInputs => base.usesSplitWidthInputs;

  @override
  bool get usesArchInput => base.usesArchInput;

  /// The base's count: collars keep the base's numbers, so the drawings do
  /// too. Which of them this window offers is the collar layout's business.
  @override
  int get collarCount => base.collarCount;

  @override
  Map<int, List<String>> get sectionsByCollar => <int, List<String>>{
    for (final MapEntry<int, List<String>> entry in base.sectionsByCollar.entries)
      if (variant.collars.contains(entry.key))
        entry.key: <String>[
          for (final String section in entry.value) variant.sectionFor(section),
        ],
  };

  @override
  Map<int, Map<String, String>> get sectionAliasesByCollar => <int, Map<String, String>>{
    for (final MapEntry<int, Map<String, String>> entry
        in base.sectionAliasesByCollar.entries)
      if (variant.collars.contains(entry.key))
        entry.key: <String, String>{
          for (final MapEntry<String, String> alias in entry.value.entries)
            variant.sectionFor(alias.key): variant.sectionFor(alias.value),
        },
  };

  @override
  Widget? overlayForCollar(int collarIndex, String? selectedSection) =>
      base.overlayForCollar(
        collarIndex,
        selectedSection == null ? null : variant.baseSectionFor(selectedSection),
      );
}
