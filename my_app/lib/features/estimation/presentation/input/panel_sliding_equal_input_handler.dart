part of 'window_input_handler.dart';

class PanelSlidingEqualInputHandler extends WindowInputHandler {
  static final Map<int, List<String>> _sections = <int, List<String>>{
    for (final MapEntry<int, List<String>> entry
        in PanelCenterFixInputHandler._sections.entries)
      entry.key: List<String>.unmodifiable(
        entry.value.where((String s) => s != 'M28'),
      ),
  };

  const PanelSlidingEqualInputHandler();

  @override
  Map<int, List<String>> get sectionsByCollar => _sections;

  @override
  Map<int, Map<String, String>> get sectionAliasesByCollar =>
      PanelCenterFixInputHandler._aliases;

  @override
  bool showDrawerForCollar(int collarIndex) =>
      sectionsByCollar.containsKey(collarIndex);

  @override
  Widget? overlayForCollar(int collarIndex, String? selectedSection) {
    if (!showDrawerForCollar(collarIndex)) return null;
    return PanelEqualOverlay(
      selectedSection: selectedSection,
      sectionAliases: aliasesForCollar(collarIndex),
      collarId: collarIndex,
      m23HighlightAllVerticals: true,
    );
  }
}
