import 'package:flutter/material.dart';

import 'collar_frame_drawing.dart';
import 'sliding_section_overlay.dart';

/// The drawing of a two-panel sliding window cut to formulas of its own --
/// the Prime Economy (EF) window and the DELIX one.
///
/// Each is the sliding window without a collar -- collar type 2, on the F
/// series -- so it is drawn exactly as that one is (Hashir, Oct 2026). Only
/// the profiles differ, and each lights the part of the drawing it is cut
/// for.
class OwnSlidingOverlay extends StatelessWidget implements CollarFrameDrawing {
  const OwnSlidingOverlay({
    super.key,
    required this.windowCode,
    required this.selectedSection,
  });

  /// The window drawn: "SPE_win", "SDX_win".
  final String windowCode;

  /// The profile picked in the sidebar, or null for none.
  final String? selectedSection;

  /// The collar it is drawn as: none on any side.
  static const int drawnAsCollar = 2;

  /// The parts of the drawing each window's profiles are cut for.
  static const Map<String, Map<String, Set<SlidingPart>>> partsByWindow =
      <String, Map<String, Set<SlidingPart>>>{
    // Prime Economy: EF30 the sides, EF27 the head, EF26A the sill, EF25 the
    // top rails, EF24 the bottom ones, EF22 the outer stiles, EF28 the two
    // meeting at the centre, D29 the net.
    'SPE_win': <String, Set<SlidingPart>>{
      'EF30': <SlidingPart>{SlidingPart.leftJamb, SlidingPart.rightJamb},
      'EF27': <SlidingPart>{SlidingPart.head},
      'EF26A': <SlidingPart>{SlidingPart.sill},
      'EF25': <SlidingPart>{SlidingPart.topRails},
      'EF24': <SlidingPart>{SlidingPart.bottomRails},
      'EF22': <SlidingPart>{SlidingPart.outerStiles},
      'EF28': <SlidingPart>{SlidingPart.centreStiles},
      'D29': <SlidingPart>{SlidingPart.net},
    },
    // DELIX: D30 the sides, D27 the head, D26A the sill, M23 the outer
    // stiles, M28 the two at the centre, D25 the top rails, M24 the bottom
    // ones, D29 the net.
    'SDX_win': <String, Set<SlidingPart>>{
      'D30': <SlidingPart>{SlidingPart.leftJamb, SlidingPart.rightJamb},
      'D27': <SlidingPart>{SlidingPart.head},
      'D26A': <SlidingPart>{SlidingPart.sill},
      'M23': <SlidingPart>{SlidingPart.outerStiles},
      'M28': <SlidingPart>{SlidingPart.centreStiles},
      'D25': <SlidingPart>{SlidingPart.topRails},
      'M24': <SlidingPart>{SlidingPart.bottomRails},
      'D29': <SlidingPart>{SlidingPart.net},
    },
  };

  /// The parts [windowCode]'s profiles light; empty for a window not drawn
  /// here.
  static Map<String, Set<SlidingPart>> partsFor(String windowCode) =>
      partsByWindow[windowCode] ?? const <String, Set<SlidingPart>>{};

  /// Where the frame is drawn: where the sliding window draws its own.
  static Rect frameIn(Size size) => SlidingSectionOverlay.frameIn(size);

  @override
  Rect collarFrameIn(Size size) => frameIn(size);

  @override
  Widget build(BuildContext context) {
    final String? picked = selectedSection;
    return SlidingSectionOverlay(
      key: const Key('own_sliding_drawing'),
      selectedSection: null,
      collarId: drawnAsCollar,
      // Nothing picked: the whole drawing, every label. A profile it does not
      // have lights nothing, rather than something it is not.
      litParts: picked == null
          ? null
          : (partsFor(windowCode)[picked] ?? const <SlidingPart>{}),
    );
  }
}
