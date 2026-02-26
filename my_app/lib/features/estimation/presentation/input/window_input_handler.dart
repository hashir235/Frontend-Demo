import 'package:flutter/widgets.dart';

import '../../models/window_type.dart';
import '../../widgets/panel_equal_overlay.dart';
import '../../widgets/panel_center_fix_overlay.dart';
import '../../widgets/panel_center_slide_overlay.dart';
import '../../widgets/sliding_corner_center_fix_overlay.dart';
import '../../widgets/sliding_m_section_overlay.dart';
import '../../widgets/sliding_section_overlay.dart';

part 'sliding_window_input_handler.dart';
part 'sliding_window_m_section_input_handler.dart';
part 'panel_center_fix_input_handler.dart';
part 'panel_center_slide_input_handler.dart';
part 'panel_equal_input_handler.dart';
part 'panel_sliding_equal_input_handler.dart';
part 'panel_m_section_input_handlers.dart';
part 'sliding_corner_center_fix_input_handler.dart';

/// Base class for window-specific input behavior.
abstract class WindowInputHandler {
  const WindowInputHandler();

  /// Number of collars available for this window input.
  int get collarCount => 14;

  /// Sections to show in the drawer for a given collar.
  List<String> sectionsForCollar(int collarIndex) =>
      sectionsByCollar[collarIndex] ?? const [];

  /// Whether the drawer should be shown for this collar.
  bool showDrawerForCollar(int collarIndex) =>
      sectionsByCollar.containsKey(collarIndex);

  /// Optional overlay painter/widget for the given collar.
  Widget? overlayForCollar(int collarIndex, String? selectedSection) => null;

  /// Map of collarIndex -> section list (override per window).
  Map<int, List<String>> get sectionsByCollar => const {};

  /// Map of collarIndex -> alias map (baseKey -> aliasKey).
  Map<int, Map<String, String>> get sectionAliasesByCollar => const {};

  Map<String, String> aliasesForCollar(int collarIndex) =>
      sectionAliasesByCollar[collarIndex] ?? const {};
}

class DefaultInputHandler extends WindowInputHandler {
  const DefaultInputHandler();
}

WindowInputHandler handlerForWindow(WindowType node) {
  switch (node.codeName) {
    case 'S_win':
      return const SlidingWindowInputHandler();
    case 'MS_win':
      return const SlidingWindowMSectionInputHandler();
    case 'PF3_win':
      return const PanelCenterFixInputHandler();
    case 'PS4_win':
      return const PanelCenterSlideInputHandler();
    case 'EF3_win':
      return const PanelEqualInputHandler();
    case 'ES3_win':
      return const PanelSlidingEqualInputHandler();
    case 'MPF3_win':
      return const PanelMCenterFixInputHandler();
    case 'MPS4_win':
      return const PanelMCenterSlideInputHandler();
    case 'MEF3_win':
      return const PanelMEqualInputHandler();
    case 'MES3_win':
      return const PanelMSlidingEqualInputHandler();
    case 'SCF_win':
    case 'MSCF_win':
      return const SlidingCornerCenterFixInputHandler();
    default:
      return const DefaultInputHandler();
  }
}
