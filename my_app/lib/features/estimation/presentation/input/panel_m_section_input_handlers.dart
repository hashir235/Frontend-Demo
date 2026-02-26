part of 'window_input_handler.dart';

List<String> _toPanelMSections(
  List<String> source, {
  required bool removeM28,
}) {
  final List<String> out = <String>[];
  for (final String code in source) {
    if (code == 'D29') continue;
    if (removeM28 && code == 'M28') continue;
    switch (code) {
      case 'DC30F':
        out.add('M30F');
        break;
      case 'DC30C':
        out.add('M30');
        break;
      case 'DC26F':
        out.add('M26F');
        break;
      case 'DC26C':
        out.add('M26');
        break;
      default:
        out.add(code);
    }
  }
  return out;
}

Map<String, String> _panelMAliasesForSections(List<String> sections) {
  return <String, String>{
    if (sections.contains('M30F')) 'DC30F': 'M30F',
    if (sections.contains('M30')) 'DC30C': 'M30',
    if (sections.contains('M26F')) 'DC26F': 'M26F',
    if (sections.contains('M26')) 'DC26C': 'M26',
  };
}

Map<int, List<String>> _buildPanelMSections(
  Map<int, List<String>> source, {
  required bool removeM28,
}) {
  return <int, List<String>>{
    for (final MapEntry<int, List<String>> entry in source.entries)
      entry.key: List<String>.unmodifiable(
        _toPanelMSections(entry.value, removeM28: removeM28),
      ),
  };
}

Map<int, Map<String, String>> _buildPanelMAliases(Map<int, List<String>> sections) {
  return <int, Map<String, String>>{
    for (final MapEntry<int, List<String>> entry in sections.entries)
      entry.key: Map<String, String>.unmodifiable(
        _panelMAliasesForSections(entry.value),
      ),
  };
}

class PanelMCenterFixInputHandler extends WindowInputHandler {
  static final Map<int, List<String>> _sections = _buildPanelMSections(
    PanelCenterFixInputHandler._sections,
    removeM28: false,
  );
  static final Map<int, Map<String, String>> _aliases = _buildPanelMAliases(
    _sections,
  );

  const PanelMCenterFixInputHandler();

  @override
  Map<int, List<String>> get sectionsByCollar => _sections;

  @override
  Map<int, Map<String, String>> get sectionAliasesByCollar => _aliases;

  @override
  bool showDrawerForCollar(int collarIndex) => _sections.containsKey(collarIndex);

  @override
  Widget? overlayForCollar(int collarIndex, String? selectedSection) {
    if (!showDrawerForCollar(collarIndex)) return null;
    return PanelCenterFixOverlay(
      selectedSection: selectedSection,
      sectionAliases: aliasesForCollar(collarIndex),
      collarId: collarIndex,
    );
  }
}

class PanelMCenterSlideInputHandler extends WindowInputHandler {
  static final Map<int, List<String>> _sections = _buildPanelMSections(
    PanelCenterSlideInputHandler._sections,
    removeM28: false,
  );
  static final Map<int, Map<String, String>> _aliases = _buildPanelMAliases(
    _sections,
  );

  const PanelMCenterSlideInputHandler();

  @override
  Map<int, List<String>> get sectionsByCollar => _sections;

  @override
  Map<int, Map<String, String>> get sectionAliasesByCollar => _aliases;

  @override
  bool showDrawerForCollar(int collarIndex) => _sections.containsKey(collarIndex);

  @override
  Widget? overlayForCollar(int collarIndex, String? selectedSection) {
    if (!showDrawerForCollar(collarIndex)) return null;
    return PanelCenterSlideOverlay(
      selectedSection: selectedSection,
      sectionAliases: aliasesForCollar(collarIndex),
      collarId: collarIndex,
    );
  }
}

class PanelMEqualInputHandler extends WindowInputHandler {
  static final Map<int, List<String>> _sections = _buildPanelMSections(
    PanelCenterFixInputHandler._sections,
    removeM28: false,
  );
  static final Map<int, Map<String, String>> _aliases = _buildPanelMAliases(
    _sections,
  );

  const PanelMEqualInputHandler();

  @override
  Map<int, List<String>> get sectionsByCollar => _sections;

  @override
  Map<int, Map<String, String>> get sectionAliasesByCollar => _aliases;

  @override
  bool showDrawerForCollar(int collarIndex) => _sections.containsKey(collarIndex);

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

class PanelMSlidingEqualInputHandler extends WindowInputHandler {
  static final Map<int, List<String>> _sections = _buildPanelMSections(
    PanelSlidingEqualInputHandler._sections,
    removeM28: true,
  );
  static final Map<int, Map<String, String>> _aliases = _buildPanelMAliases(
    _sections,
  );

  const PanelMSlidingEqualInputHandler();

  @override
  Map<int, List<String>> get sectionsByCollar => _sections;

  @override
  Map<int, Map<String, String>> get sectionAliasesByCollar => _aliases;

  @override
  bool showDrawerForCollar(int collarIndex) => _sections.containsKey(collarIndex);

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
