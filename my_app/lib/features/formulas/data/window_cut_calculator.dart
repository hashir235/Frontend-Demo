/// Working out one window's cut list in the app.
library;

import '../model/formula_expression.dart';
import '../model/formula_slot.dart';
import '../model/formula_window_key.dart';
import '../model/window_measurements.dart';
import 'formula_book.dart';

/// Centimetres in a foot.
const double _feetInCm = 30.48;

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

    final Map<String, double> variables = <String, double>{
      ...measured.values,
      'feet': _feetInCm,
      ...margins,
    };

    final List<CutPiece> pieces = <CutPiece>[];
    for (final EffectiveSection section in sections) {
      final String name = sectionAliases[section.section] ?? section.section;
      for (final EffectiveFormula piece in section.pieces) {
        final FormulaSlot slot = piece.slot;

        // A formula naming a margin nobody has set reads it as no margin at
        // all, which is what the engine does: an unset margin is zero, not an
        // error.
        final String? margin = slot.marginName;
        if (margin != null && !variables.containsKey(margin)) {
          variables[margin] = 0;
        }

        final FormulaResult result = slot.lengthFor(variables);
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
      final FormulaResult height = pane.pieces[0].slot.lengthFor(variables);
      final FormulaResult width = pane.pieces[1].slot.lengthFor(variables);

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

    return WindowCutList._(pieces, problems, glass: glass);
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
