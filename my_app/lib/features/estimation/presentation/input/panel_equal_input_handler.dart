part of 'window_input_handler.dart';

class PanelEqualInputHandler extends WindowInputHandler {
  const PanelEqualInputHandler();

  @override
  Map<int, List<String>> get sectionsByCollar =>
      PanelCenterFixInputHandler._sections;

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
    );
  }
}
