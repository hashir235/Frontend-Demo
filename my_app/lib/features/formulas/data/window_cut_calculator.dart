/// Working out one window's cut list in the app.
library;

import '../../estimation/models/door_strip.dart';
import '../../estimation/models/window_variant.dart';
import '../model/formula_expression.dart';
import '../model/formula_slot.dart';
import '../model/formula_window_key.dart';
import '../model/piece_size.dart';
import '../model/window_measurements.dart';
import '../model/window_sides.dart';
import 'formula_book.dart';

/// Centimetres in a foot.
const double _feetInCm = 30.48;

/// The sash rail and the names variant windows give it -- M24 on the ordinary
/// windows, EC24, ET24 and ET24A on the Economy ones.
const Set<String> m24Sections = <String>{'M24', 'EC24', 'ET24', 'ET24A'};

/// The sash's outer stile and the names variant windows give it.
const Set<String> m23Sections = <String>{'M23', 'EC23', 'ET23'};

/// The engine's two-panel sliding windows: their two M23 are one at the
/// window's left and one at its right. On a three-panel or a corner window
/// they are not, and keep the smaller height (Hashir, Oct 2026).
const Set<String> _twoPanelWindows = <String>{'S_win', 'SM_win'};

/// The engine's fix windows -- the fix window and the corner fix, on every
/// frame (D54, D51, D42). Measured side by side, every piece of one that
/// belongs to a side is cut to that side exactly as measured, however close
/// the side facing it: the bead as the frame is (Hashir, Oct 2026). Top
/// 34.4cm and bottom 37cm is a 34.4 top and a 37 bottom, not two of either.
const Set<String> _fixWindows = <String>{'F_win', 'FC_win'};

/// One length of aluminium to be cut.
class CutPiece {
  const CutPiece({
    required this.section,
    required this.label,
    required this.lengthFt,
  });

  /// The profile it comes off, under whatever name this workshop calls it.
  final String section;

  /// What it is called on the cutting list -- "HL", "WT".
  final String label;

  final double lengthFt;

  @override
  String toString() => '$section $label ${lengthFt.toStringAsFixed(3)}ft';
}

/// One pane of glass, at the size it is cut to.
class GlassPiece {
  const GlassPiece({required this.heightCm, required this.widthCm});

  /// In centimetres, both. Glass carries no cutting margin -- the blade's
  /// allowance is an aluminium matter -- and no conversion to feet, because a
  /// sheet is measured and scored in centimetres from end to end.
  final double heightCm;
  final double widthCm;

  @override
  String toString() =>
      '${heightCm.toStringAsFixed(1)} x ${widthCm.toStringAsFixed(1)} cm';
}

/// A window's cut list, or the reason there isn't one.
class WindowCutList {
  const WindowCutList._(this.pieces, this.problems, {this.glass = const <GlassPiece>[]});

  final List<CutPiece> pieces;

  /// The panes this window takes, in the order the engine cuts them.
  final List<GlassPiece> glass;

  /// Everything that stopped a piece being worked out. A cut list with any of
  /// these is not a cut list -- it is shown to the fabricator instead.
  final List<String> problems;

  bool get isUsable => problems.isEmpty;
}

/// What a window's own settings say about the metal it is cut from.
class WindowCutRequest {
  const WindowCutRequest({
    required this.isFabrication,
    required this.appWindowCode,
    required this.collarIndex,
    required this.unitMode,
    required this.heightValue,
    required this.widthValue,
    this.leftWidthValue,
    this.rightWidthValue,
    this.archValue,
    this.lockType,
    this.rubberType,
    this.addBottom = false,
    this.addTee = false,
    this.addNet = false,
    this.backCollarCm = 1.7,
    this.pieceSizes = const <PieceSize>[],
    this.sideSizes = const SideSizes.empty(),
    this.leaveOut = const <String>{},
    this.strip,
  });

  final bool isFabrication;
  final String appWindowCode;
  final int collarIndex;
  final String unitMode;
  final String heightValue;
  final String widthValue;
  final String? leftWidthValue;
  final String? rightWidthValue;
  final String? archValue;
  final int? lockType;
  final String? rubberType;
  final bool addBottom;
  final bool addTee;
  final bool addNet;
  final double backCollarCm;

  /// Pieces of this window a fabricator set to a size of their own.
  final List<PieceSize> pieceSizes;

  /// This window measured one side at a time, when it was. Empty for a window
  /// measured the usual way, which is nearly all of them.
  final SideSizes sideSizes;

  /// Profiles this window is not cut from, though its formulas have them: an
  /// optional one (D31) the fabricator left switched off.
  final Set<String> leaveOut;

  /// Strips laid in a door in place of its glass, or null for glass.
  final DoorStrip? strip;

  String get context => isFabrication ? 'fabrication' : 'estimation';
}

/// Cuts a window to the formulas this workshop actually uses.
///
/// This is the app doing what the engine has always done. It exists so a
/// fabricator can change a formula and see the change in their own cut list,
/// which is only possible if the cutting happens where the formulas are.
///
/// It is held to the engine piece by piece, on real projects, before it is
/// allowed to replace it. Until then both run and their answers are compared.
class WindowCutCalculator {
  const WindowCutCalculator(this.book);

  final FormulaBook book;

  /// One window's pieces.
  ///
  /// [margins] is the workshop's cutting margins: for fabrication, the single
  /// margin under the key `cm`; for estimation, one per profile under its own
  /// name. [sectionAliases] renames a profile where the workshop calls it
  /// something else, exactly as the engine's own section lookup does.
  WindowCutList compute(
    WindowCutRequest request, {
    required Map<String, double> margins,
    Map<String, String> sectionAliases = const <String, String>{},
  }) {
    final List<String> problems = <String>[];

    final Set<String> dimensions = book.catalogue.dimensionsFor(
      '${request.context}/${_engineWindowOf(request) ?? ''}',
    );

    final FormulaWindowKey? key = FormulaWindowKey.of(
      context: request.context,
      appWindowCode: request.appWindowCode,
      dimensions: dimensions,
      collarIndex: request.collarIndex,
      lockType: request.lockType,
      rubberType: request.rubberType,
      addBottom: request.addBottom,
      addTee: request.addTee,
      addNet: request.addNet,
      backCollarCm: request.backCollarCm,
    );

    if (key == null) {
      return WindowCutList._(const <CutPiece>[], <String>[
        'Quick AL does not know how to cut a ${request.appWindowCode} '
            'with these settings.',
      ]);
    }

    final List<EffectiveSection>? sections = book.sectionsFor(key);
    if (sections == null) {
      return WindowCutList._(const <CutPiece>[], <String>[
        'There are no formulas for ${request.appWindowCode} at collar '
            '${request.collarIndex} with these settings.',
      ]);
    }

    // A window measured side by side is read from its sides; every other
    // window from its height and width, exactly as before.
    final SideMeasurements? sides = request.sideSizes.isEmpty
        ? null
        : SideMeasurements.read(
            unitMode: request.unitMode,
            sizes: request.sideSizes,
            sides: WindowSide.orderedFrom(
              book.catalogue.frameSideLabelsFor(key),
            ),
          );
    if (request.sideSizes.isNotEmpty && sides == null) {
      return WindowCutList._(const <CutPiece>[], <String>[
        SideMeasurements.lastProblem ?? 'This window\'s sides cannot be read.',
      ]);
    }

    Map<String, double>? measuredValues = sides?.inner;
    if (measuredValues == null) {
      final WindowMeasurements? measured = WindowMeasurements.read(
        isFabrication: request.isFabrication,
        unitMode: request.unitMode,
        heightValue: request.heightValue,
        widthValue: request.widthValue,
        leftWidthValue: request.leftWidthValue,
        rightWidthValue: request.rightWidthValue,
        archValue: request.archValue,
      );
      if (measured == null) {
        return WindowCutList._(const <CutPiece>[], <String>[
          WindowMeasurements.lastProblem ?? 'This window\'s measurements cannot be read.',
        ]);
      }
      measuredValues = measured.values;
    }

    final Map<String, double> variables = <String, double>{
      ...measuredValues,
      'feet': _feetInCm,
      ...margins,
    };

    // Measured side by side (Hashir, Oct 2026), the frame is cut to each
    // side exactly as measured, however close the pair. Inside it, a piece
    // that belongs to one side is cut to it only when that side is more than
    // 2 suter from the one facing it; otherwise to the smaller of the pair,
    // already standing in [variables]. Which side a piece belongs to, if any,
    // is worked out per profile: the frame's pieces and anything named for a
    // side by their labels, the rails and the outer stiles by where they sit.
    final Set<String> frameSections =
        sides == null ? const <String>{} : book.catalogue.frameSectionsFor(key.windowKey);
    final OwnWindow? ownWindow = WindowVariants.ownOf(request.appWindowCode);
    final String? engineWindow = _engineWindowOf(request);
    // A fix window's every side-labelled piece is cut as measured, as a frame
    // is; see [_fixWindows].
    final bool everySideAsMeasured = _fixWindows.contains(engineWindow);

    final List<CutPiece> pieces = <CutPiece>[];
    for (final EffectiveSection section in sections) {
      if (request.leaveOut.contains(section.section)) continue;
      final String name = sectionAliases[section.section] ?? section.section;
      final bool isFrame =
          everySideAsMeasured || frameSections.contains(section.section);
      final List<String?> pieceSides = sides == null
          ? const <String?>[]
          : _sidesOf(section, own: ownWindow, engineWindow: engineWindow);
      for (int index = 0; index < section.pieces.length; index++) {
        final EffectiveFormula piece = section.pieces[index];
        final FormulaSlot slot = piece.slot;

        // A formula naming a margin nobody has set reads it as no margin at
        // all, which is what the engine does: an unset margin is zero, not an
        // error.
        final String? margin = slot.marginName;
        if (margin != null && !variables.containsKey(margin)) {
          variables[margin] = 0;
        }

        final Map<String, double> forPiece = _withSide(
          variables,
          sides,
          index < pieceSides.length ? pieceSides[index] : null,
          isFrame: isFrame,
        );
        final ({Map<String, double>? variables, String? problem}) own =
            _variablesFor(piece, forPiece, request.pieceSizes);
        if (own.problem != null) {
          problems.add(own.problem!);
          continue;
        }

        final FormulaResult result = slot.lengthFor(own.variables!);
        if (!result.isUsable) {
          problems.add(result.problem!);
          continue;
        }
        pieces.add(CutPiece(
          section: name,
          label: slot.label,
          lengthFt: result.value!,
        ));
      }
    }

    // The panes. Worked out here for the same reason the aluminium is: a
    // workshop that has changed a glass formula has to get glass cut to it.
    final List<GlassPiece> glass = <GlassPiece>[];
    for (final EffectiveSection pane in book.glassFor(key)) {
      if (pane.pieces.length != 2) continue;
      final ({Map<String, double>? variables, String? problem}) ownHeight =
          _variablesFor(pane.pieces[0], variables, request.pieceSizes);
      final ({Map<String, double>? variables, String? problem}) ownWidth =
          _variablesFor(pane.pieces[1], variables, request.pieceSizes);
      final String? stale = ownHeight.problem ?? ownWidth.problem;
      if (stale != null) {
        problems.add(stale);
        continue;
      }
      final FormulaResult height =
          pane.pieces[0].slot.lengthFor(ownHeight.variables!);
      final FormulaResult width =
          pane.pieces[1].slot.lengthFor(ownWidth.variables!);

      // A pane that comes out at nothing is one the engine does not cut
      // either -- it refuses anything that is not positive. Saying so is the
      // difference between a missing pane noticed at the desk and one noticed
      // when the frame is already up.
      if (!height.isUsable || !width.isUsable) {
        problems.add('${pane.displayName}: '
            '${height.problem ?? width.problem}');
        continue;
      }
      glass.add(GlassPiece(heightCm: height.value!, widthCm: width.value!));
    }

    // Strips in place of the glass. Each pane is covered by strips as long as
    // it is wide, laid one above another until they reach its height -- P1 +
    // P2 + ... >= the height -- and the door takes no glass.
    final DoorStrip? strip = request.strip;
    if (strip != null) {
      final List<GlassPiece> panes = request.isFabrication
          ? glass
          : _doorGlassForEstimation(request, measuredValues, problems);
      int number = 0;
      for (final GlassPiece pane in panes) {
        final double lengthFt = request.isFabrication
            // As the fabrication formulas are: (size + cm) / feet, the
            // margin added for the optimizer and taken off the cutting list.
            ? (pane.widthCm + (margins['cm'] ?? 0)) / _feetInCm
            // As the estimation ones are: size + the profile's own margin.
            : pane.widthCm / _feetInCm + (margins['cm_${strip.section}'] ?? 0);
        for (int i = 0; i < strip.piecesFor(pane.heightCm); i++) {
          number++;
          pieces.add(CutPiece(section: strip.section, label: 'P$number', lengthFt: lengthFt));
        }
      }
      return WindowCutList._(pieces, problems);
    }

    return WindowCutList._(pieces, problems, glass: glass);
  }

  /// A door's panes for estimation, which has no glass formulas of its own:
  /// the same door's fabrication ones (with the plain 1.7cm back collar),
  /// worked out on its measurements in centimetres.
  List<GlassPiece> _doorGlassForEstimation(
    WindowCutRequest request,
    Map<String, double> measured,
    List<String> problems,
  ) {
    final String? window =
        FormulaWindowKey.engineWindowFor(request.appWindowCode, 'fabrication')?.window;
    final FormulaWindowKey? key = window == null
        ? null
        : FormulaWindowKey.of(
            context: 'fabrication',
            appWindowCode: request.appWindowCode,
            dimensions: book.catalogue.dimensionsFor('fabrication/$window'),
            collarIndex: request.collarIndex,
            addBottom: request.addBottom,
            addTee: request.addTee,
          );
    final List<EffectiveSection> panes =
        key == null ? const <EffectiveSection>[] : book.glassFor(key);
    if (panes.isEmpty) {
      problems.add('Quick AL cannot size strips for this door: it has no '
          'glass size to cover.');
      return const <GlassPiece>[];
    }
    final Map<String, double> inCm = <String, double>{
      for (final MapEntry<String, double> entry in measured.entries)
        entry.key: entry.value * _feetInCm,
      'feet': _feetInCm,
    };
    final List<GlassPiece> out = <GlassPiece>[];
    for (final EffectiveSection pane in panes) {
      if (pane.pieces.length != 2) continue;
      final FormulaResult height = pane.pieces[0].slot.lengthFor(inCm);
      final FormulaResult width = pane.pieces[1].slot.lengthFor(inCm);
      if (!height.isUsable || !width.isUsable) {
        problems.add('${pane.displayName}: ${height.problem ?? width.problem}');
        continue;
      }
      out.add(GlassPiece(heightCm: height.value!, widthCm: width.value!));
    }
    return out;
  }

  /// The measurements one piece is cut from when the window was measured side
  /// by side: its own [side]'s -- always for a piece of the frame, and for a
  /// piece inside it when that side is more than 2 suter from the one facing
  /// it; otherwise the smaller of the pair, which [variables] already hold.
  ///
  /// A side this window was not measured on keeps the smaller too, which is
  /// the safe way round: too small can be packed out, too big cannot be put
  /// back.
  static Map<String, double> _withSide(
    Map<String, double> variables,
    SideMeasurements? sides,
    String? side, {
    required bool isFrame,
  }) {
    if (sides == null || side == null) return variables;
    if (!isFrame && !sides.isApart(side)) return variables;
    final double? own = sides.bySide[side];
    final String? dimension = WindowSide.dimension[side];
    if (own == null || dimension == null) return variables;
    if (variables[dimension] == own) return variables;
    return <String, double>{...variables, dimension: own};
  }

  /// The side each of [section]'s pieces belongs to, or null for a piece that
  /// belongs to none and is cut to the smaller of each pair.
  ///
  ///  * The frame (WT the head, WB the sill, HL and HR the jambs), and
  ///    anything inside it labelled the same way (D29's HL and WT, a door's
  ///    D50): the side its label names.
  ///  * The sash rails: the top ones to the top, the bottom ones to the
  ///    bottom.
  ///  * The two outer stiles of a two-panel sliding window: the left to the
  ///    left height, the right to the right.
  ///  * Everything else -- the stiles meeting at the centre, a three-panel or
  ///    corner window's M23, a door's Tee -- belongs to no one side.
  static List<String?> _sidesOf(
    EffectiveSection section, {
    required OwnWindow? own,
    required String? engineWindow,
  }) {
    final List<EffectiveFormula> pieces = section.pieces;
    if (own != null) {
      // Its own profiles, named by what they are.
      if (section.section == own.topRails) {
        return <String?>[for (final EffectiveFormula p in pieces) _railEnds[p.slot.dimension]?.$1];
      }
      if (section.section == own.bottomRails) {
        return <String?>[for (final EffectiveFormula p in pieces) _railEnds[p.slot.dimension]?.$2];
      }
      if (section.section == own.outerStiles && pieces.length == 2) {
        return const <String?>[WindowSide.left, WindowSide.right];
      }
    } else {
      if (m24Sections.contains(section.section)) return _railSides(pieces);
      if (m23Sections.contains(section.section) &&
          pieces.length == 2 &&
          _twoPanelWindows.contains(engineWindow)) {
        return const <String?>[WindowSide.left, WindowSide.right];
      }
    }
    return <String?>[
      for (final EffectiveFormula p in pieces)
        WindowSide.dimension.containsKey(p.slot.label) ? p.slot.label : null,
    ];
  }

  /// The top and bottom of each wall, by the measurement its rails read.
  static const Map<String, (String, String)> _railEnds = <String, (String, String)>{
    'w': (WindowSide.top, WindowSide.bottom),
    'wl': (WindowSide.topLeft, WindowSide.bottomLeft),
    'wr': (WindowSide.topRight, WindowSide.bottomRight),
  };

  /// The side of each M24 rail.
  ///
  /// A window's rails are listed a wall at a time, the top ones first: W1 W2
  /// then W3 W4 on a sliding window, W1s W2f W3s then W4s W5f W6s on a
  /// three-panel one, WL1 WL2 then WL3 WL4 on a corner's left wall (and its
  /// right wall the same by itself). So of each wall's rails the first half
  /// are its top and the rest its bottom. A wall with an odd number of rails
  /// belongs to neither.
  static List<String?> _railSides(List<EffectiveFormula> rails) {
    final List<String?> out = List<String?>.filled(rails.length, null);
    final Map<String, List<int>> byWall = <String, List<int>>{};
    for (int index = 0; index < rails.length; index++) {
      byWall.putIfAbsent(rails[index].slot.dimension, () => <int>[]).add(index);
    }
    byWall.forEach((String dimension, List<int> wall) {
      final (String, String)? ends = _railEnds[dimension];
      if (ends == null || wall.length.isOdd) return;
      final int half = wall.length ~/ 2;
      for (int i = 0; i < wall.length; i++) {
        out[wall[i]] = i < half ? ends.$1 : ends.$2;
      }
    });
    return out;
  }

  /// The measurements one piece is cut from: the window's own, with this
  /// piece's size of its own standing in where the fabricator set one.
  ///
  /// A size set against a measurement the window no longer has is refused
  /// rather than applied or ignored. Applying it would cut to a number chosen
  /// for a different window; ignoring it would quietly cut to the window's
  /// size when somebody asked for another. Either is a wrong piece nobody was
  /// told about, so the job stops and says which piece and why.
  static ({Map<String, double>? variables, String? problem}) _variablesFor(
    EffectiveFormula piece,
    Map<String, double> variables,
    List<PieceSize> sizes,
  ) {
    if (sizes.isEmpty) return (variables: variables, problem: null);
    final PieceSize? own = PieceSize.find(sizes, piece.ref);
    if (own == null) return (variables: variables, problem: null);

    final String dimension = piece.slot.dimension;
    final double? current = variables[dimension];
    if (own.dimension != dimension || current == null || !own.standsFor(current)) {
      return (
        variables: null,
        problem: '${piece.slot.section} ${piece.slot.label} has a size of its '
            'own that was set before this window\'s measurements changed. '
            'Open the window and set it again on the formula screen.',
      );
    }
    return (
      variables: <String, double>{...variables, dimension: own.size},
      problem: null,
    );
  }

  /// The engine's name for a window, so its configuration dimensions can be
  /// looked up before the key itself is built.
  String? _engineWindowOf(WindowCutRequest request) {
    if (!FormulaWindowKey.knows(request.appWindowCode)) return null;
    // Built with an empty dimension set purely to learn the engine's name for
    // this window; the real key is built once the dimensions are known.
    final FormulaWindowKey? probe = FormulaWindowKey.of(
      context: request.context,
      appWindowCode: request.appWindowCode,
      dimensions: const <String>{},
      collarIndex: request.collarIndex,
    );
    return probe?.window;
  }

  /// A whole job's pieces, gathered the way the engine gathers them.
  ///
  /// Returns the pieces in window order, each carrying which window it came
  /// from, because that is what a cutting list has to say and what the parity
  /// check compares.
  List<JobCutPiece> computeJob(
    List<({int winNo, WindowCutRequest request})> windows, {
    required Map<String, double> margins,
    Map<String, String> sectionAliases = const <String, String>{},
    required void Function(int winNo, List<String> problems) onProblem,
  }) {
    final List<JobCutPiece> all = <JobCutPiece>[];
    for (final ({int winNo, WindowCutRequest request}) entry in windows) {
      final WindowCutList list = compute(
        entry.request,
        margins: margins,
        sectionAliases: sectionAliases,
      );
      if (list.problems.isNotEmpty) {
        onProblem(entry.winNo, list.problems);
      }
      for (final CutPiece piece in list.pieces) {
        all.add(JobCutPiece(winNo: entry.winNo, piece: piece));
      }
    }
    return all;
  }
}

/// A cut piece, and which window in the job it belongs to.
class JobCutPiece {
  const JobCutPiece({required this.winNo, required this.piece});

  final int winNo;
  final CutPiece piece;

  @override
  String toString() => 'win $winNo: $piece';
}
