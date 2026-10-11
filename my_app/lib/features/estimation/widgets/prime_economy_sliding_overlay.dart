import 'package:flutter/material.dart';

import 'collar_frame_drawing.dart';
import 'sliding_section_overlay.dart';

/// The Prime Economy sliding window's drawing.
///
/// It is the sliding window without a collar -- collar type 2, on the F
/// series -- so it is drawn exactly as that one is (Hashir, Oct 2026). Only
/// its profiles differ, and each lights the part of the drawing it is cut
/// for:
///
///  * EF30 -- the frame's two sides (HL, HR)
///  * EF27 -- the frame's head (WT); EF26A its sill (WB)
///  * EF25 -- each panel's top rail; EF24 each one's bottom rail
///  * EF22 -- each panel's outer stile; EF28 the two meeting at the centre
///  * D29  -- the net over one panel
class PrimeEconomySlidingOverlay extends StatelessWidget implements CollarFrameDrawing {
  const PrimeEconomySlidingOverlay({super.key, required this.selectedSection});

  /// The profile picked in the sidebar, or null for none.
  final String? selectedSection;

  /// The collar it is drawn as: none on any side.
  static const int drawnAsCollar = 2;

  /// The parts of the drawing each of its profiles is cut for.
  static const Map<String, Set<SlidingPart>> partsBySection = <String, Set<SlidingPart>>{
    'EF30': <SlidingPart>{SlidingPart.leftJamb, SlidingPart.rightJamb},
    'EF27': <SlidingPart>{SlidingPart.head},
    'EF26A': <SlidingPart>{SlidingPart.sill},
    'EF25': <SlidingPart>{SlidingPart.topRails},
    'EF24': <SlidingPart>{SlidingPart.bottomRails},
    'EF22': <SlidingPart>{SlidingPart.outerStiles},
    'EF28': <SlidingPart>{SlidingPart.centreStiles},
    'D29': <SlidingPart>{SlidingPart.net},
  };

  /// Where the frame is drawn: where the sliding window draws its own.
  static Rect frameIn(Size size) => SlidingSectionOverlay.frameIn(size);

  @override
  Rect collarFrameIn(Size size) => frameIn(size);

  @override
  Widget build(BuildContext context) {
    final String? picked = selectedSection;
    return SlidingSectionOverlay(
      key: const Key('prime_economy_drawing'),
      selectedSection: null,
      collarId: drawnAsCollar,
      // Nothing picked: the whole drawing, every label. A profile it does not
      // have lights nothing, rather than something it is not.
      litParts: picked == null
          ? null
          : (partsBySection[picked] ?? const <SlidingPart>{}),
    );
  }
}
