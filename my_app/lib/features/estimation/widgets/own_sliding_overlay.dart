import 'package:flutter/material.dart';

import '../models/collar_layout.dart';
import 'collar_frame_drawing.dart';
import 'sliding_section_overlay.dart';

/// The drawing of a two-panel sliding window cut to formulas of its own --
/// the Prime Economy (EF) window, the DELUXE one and the Double Glaze one.
///
/// The first two are the sliding window without a collar -- collar type 2,
/// on the F series -- so they are drawn exactly as that one is (Hashir, Oct
/// 2026). Double Glaze is drawn at the collar picked. Only the profiles
/// differ, and each lights the part of the drawing it is cut for.
class OwnSlidingOverlay extends StatelessWidget implements CollarFrameDrawing {
  const OwnSlidingOverlay({
    super.key,
    required this.windowCode,
    required this.selectedSection,
    this.collar = drawnAsCollar,
  });

  /// The window drawn: "SPE_win", "SDX_win", "SDG_win".
  final String windowCode;

  /// The profile picked in the sidebar, or null for none.
  final String? selectedSection;

  /// The collar it is drawn at.
  final int collar;

  /// The collar a window that has no other is drawn as: none on any side.
  static const int drawnAsCollar = 2;

  /// The parts of the Double Glaze window each of its profiles lights at
  /// [collar]: DG26F the sides of the frame with a collar, DG26 the sides
  /// without; DG23 everything M23, M24 and M28 are on a sliding window.
  static Map<String, Set<SlidingPart>> doubleGlazeParts(int collar) {
    const Map<CollarSide, SlidingPart> frameParts = <CollarSide, SlidingPart>{
      CollarSide.top: SlidingPart.head,
      CollarSide.bottom: SlidingPart.sill,
      CollarSide.left: SlidingPart.leftJamb,
      CollarSide.right: SlidingPart.rightJamb,
    };
    final Set<CollarSide> collared =
        CollarLayout.forWindow('S_win')?.sidesWithCollar(collar) ?? const <CollarSide>{};
    return <String, Set<SlidingPart>>{
      'DG26F': <SlidingPart>{
        for (final MapEntry<CollarSide, SlidingPart> side in frameParts.entries)
          if (collared.contains(side.key)) side.value,
      },
      'DG26': <SlidingPart>{
        for (final MapEntry<CollarSide, SlidingPart> side in frameParts.entries)
          if (!collared.contains(side.key)) side.value,
      },
      'DG23': <SlidingPart>{
        SlidingPart.outerStiles,
        SlidingPart.centreStiles,
        SlidingPart.topRails,
        SlidingPart.bottomRails,
      },
      'DG28': <SlidingPart>{SlidingPart.centreStiles},
      'DG29': <SlidingPart>{SlidingPart.net},
    };
  }

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
    // DELUXE: D30 the sides, D27 the head, D26A the sill, M23 the outer
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

  /// The parts [windowCode]'s profiles light at [collar]; empty for a window
  /// not drawn here.
  static Map<String, Set<SlidingPart>> partsFor(
    String windowCode, {
    int collar = drawnAsCollar,
  }) {
    if (windowCode == 'SDG_win') return doubleGlazeParts(collar);
    return partsByWindow[windowCode] ?? const <String, Set<SlidingPart>>{};
  }

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
      collarId: collar,
      // Nothing picked: the whole drawing, every label. A profile it does not
      // have lights nothing, rather than something it is not.
      litParts: picked == null
          ? null
          : (partsFor(windowCode, collar: collar)[picked] ?? const <SlidingPart>{}),
    );
  }
}
