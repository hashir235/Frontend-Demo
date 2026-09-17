import '../../formulas/model/piece_size.dart';
import '../../formulas/model/window_sides.dart';
import 'window_review_item.dart';

class OptimizationWindowRequest {
  final int winNo;
  final String windowCode;
  final String windowLabel;
  final int collarIndex;
  final String unitMode;
  final String heightValue;
  final String widthValue;
  final String? rightWidthValue;
  final String? leftWidthValue;
  final String? archValue;
  final String? description;
  final bool addBottom;
  final bool addTee;
  final bool addNet;
  final double backCollarCm;
  final int? lockType;
  final String? rubberType;

  /// The stock this window is made from.
  ///
  /// The engine keys its cutting piles and its rates on these, so a request
  /// that leaves them out is a request for one pile per profile -- which is
  /// what the whole job used to be. They have to be here, and not only on
  /// [WindowReviewItem], because this class is what actually goes on the wire.
  final String gauge;
  final String color;

  /// The glass this window is glazed in.
  ///
  /// It changes nothing about the cutting -- the engine prices no glass off it
  /// -- but the bill adds the glazing area up per glass, and the area is
  /// worked out here. Sending it with the window is what lets that sum be made
  /// at all.
  final String glassColor;

  const OptimizationWindowRequest({
    required this.winNo,
    required this.windowCode,
    required this.windowLabel,
    required this.collarIndex,
    required this.unitMode,
    required this.heightValue,
    required this.widthValue,
    required this.rightWidthValue,
    required this.leftWidthValue,
    required this.archValue,
    required this.description,
    required this.addBottom,
    required this.addTee,
    required this.addNet,
    required this.backCollarCm,
    required this.lockType,
    required this.rubberType,
    required this.gauge,
    required this.color,
    required this.glassColor,
    this.computedPieces,
    this.computedGlass,
    this.pieceSizes = const <PieceSize>[],
    this.sideSizes = const SideSizes.empty(),
  });

  factory OptimizationWindowRequest.fromReviewItem(
    WindowReviewItem item, {
    required bool isFabrication,
  }) {
    // Estimation cm: items are stored in raw cm (what the user typed), but
    // the estimation engine only understands inches/feet — so convert each
    // dimension to the inch.sutter encoding on the wire.
    final bool estimationCm = !isFabrication && item.unitMode == UnitMode.cm;
    String dim(String value) =>
        estimationCm ? cmDimensionToInchSutter(value) : value;
    String? dimOrNull(String? value) =>
        (value == null || value.trim().isEmpty) ? value : dim(value);

    final String unitMode = isFabrication
        ? (item.unitMode == UnitMode.inches ? 'inches' : 'cm')
        : (item.unitMode == UnitMode.feet ? 'feet' : 'inches');

    // A window measured side by side goes on the wire as the smaller of each
    // pair: that is what its glass is cut to, what its piece labels should
    // read, and the only pair the engine could make sense of. The wider edges
    // reach the frame through the lengths the app works out.
    final SideSizes sides = item.sideSizes;
    String smallest(List<String> of, String fallback) =>
        sides.smallestRaw(of, unitMode: unitMode) ?? fallback;
    final bool measuredBySide = isFabrication && sides.isNotEmpty;

    return OptimizationWindowRequest(
      winNo: item.winNo,
      windowCode: item.windowCode,
      windowLabel: item.windowLabel,
      collarIndex: item.collarIndex,
      unitMode: unitMode,
      heightValue: measuredBySide
          ? smallest(<String>[WindowSide.left, WindowSide.right], item.heightValue)
          : dim(item.heightValue),
      widthValue: measuredBySide
          ? smallest(
              <String>[
                WindowSide.top,
                WindowSide.bottom,
                WindowSide.topRight,
                WindowSide.bottomRight,
              ],
              item.widthValue,
            )
          : dim(item.widthValue),
      rightWidthValue: measuredBySide && item.rightWidthValue != null
          ? smallest(
              <String>[WindowSide.topRight, WindowSide.bottomRight],
              item.rightWidthValue!,
            )
          : dimOrNull(item.rightWidthValue),
      leftWidthValue: measuredBySide && item.leftWidthValue != null
          ? smallest(
              <String>[WindowSide.topLeft, WindowSide.bottomLeft],
              item.leftWidthValue!,
            )
          : dimOrNull(item.leftWidthValue),
      archValue: dimOrNull(item.archValue),
      description: item.description,
      addBottom: item.addBottom,
      addTee: item.addTee,
      addNet: item.addNet,
      backCollarCm: item.backCollarCm,
      lockType: item.lockType,
      rubberType: item.rubberType,
      gauge: item.material.gauge,
      color: item.material.color,
      glassColor: item.glassColor,
      pieceSizes: item.pieceSizes,
      sideSizes: measuredBySide ? sides : const SideSizes.empty(),
    );
  }

  /// Pieces of this window cut to a size of their own.
  ///
  /// Used here, where the lengths are worked out, and never sent: the engine
  /// receives the finished lengths, which already carry these sizes.
  final List<PieceSize> pieceSizes;

  /// This window's own sides, when it was measured one side at a time.
  ///
  /// Used here, where the lengths are worked out, and never sent: the engine
  /// is handed the finished lengths, which already carry each side.
  final SideSizes sideSizes;

  /// The lengths the app worked out for this window, when it did.
  ///
  /// The engine cuts to these instead of recomputing, so a formula this
  /// workshop changed is the formula the saw is set to. Null means the app did
  /// not work them out and the engine should, exactly as it always has.
  final List<Map<String, Object?>>? computedPieces;

  /// The panes of glass the app worked out for this window, when it did.
  final List<Map<String, Object?>>? computedGlass;

  /// The same window, carrying the lengths the app worked out for it.
  OptimizationWindowRequest withComputed(
    List<Map<String, Object?>> pieces,
    List<Map<String, Object?>> glass,
  ) {
    return OptimizationWindowRequest(
      winNo: winNo,
      windowCode: windowCode,
      windowLabel: windowLabel,
      collarIndex: collarIndex,
      unitMode: unitMode,
      heightValue: heightValue,
      widthValue: widthValue,
      rightWidthValue: rightWidthValue,
      leftWidthValue: leftWidthValue,
      archValue: archValue,
      description: description,
      addBottom: addBottom,
      addTee: addTee,
      addNet: addNet,
      backCollarCm: backCollarCm,
      lockType: lockType,
      rubberType: rubberType,
      gauge: gauge,
      color: color,
      glassColor: glassColor,
      computedPieces: pieces,
      computedGlass: glass,
      pieceSizes: pieceSizes,
      sideSizes: sideSizes,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (computedPieces != null) 'computedPieces': computedPieces,
      if (computedGlass != null) 'computedGlass': computedGlass,
      'winNo': winNo,
      'windowCode': windowCode,
      'windowLabel': windowLabel,
      'collarIndex': collarIndex,
      'unitMode': unitMode,
      'heightValue': heightValue,
      'widthValue': widthValue,
      'rightWidthValue': rightWidthValue,
      'leftWidthValue': leftWidthValue,
      'archValue': archValue,
      'description': description,
      'addBottom': addBottom,
      'addTee': addTee,
      'addNet': addNet,
      'backCollarCm': backCollarCm,
      'lockType': lockType,
      'rubberType': rubberType,
      'gauge': gauge,
      'color': color,
      'glassColor': glassColor,
    };
  }
}

class OptimizationRequest {
  final String? projectId;
  final String context;
  final String displayUnit;
  final String projectName;
  final String projectLocation;
  final List<OptimizationWindowRequest> windows;

  const OptimizationRequest({
    required this.projectId,
    required this.context,
    required this.displayUnit,
    required this.projectName,
    required this.projectLocation,
    required this.windows,
  });

  factory OptimizationRequest.fromReviewItems(
    List<WindowReviewItem> items, {
    String? projectId,
    String context = 'estimation',
    String displayUnit = 'ft',
    required String projectName,
    required String projectLocation,
  }) {
    final bool isFabrication = context.toLowerCase() == 'fabrication';
    // When an estimation session is entirely in cm, ask the engine to render
    // the cutting report in cm too, so cut sizes read in the unit the user
    // entered. Mixed-unit sessions keep the default feet display.
    final bool allCm =
        !isFabrication &&
        items.isNotEmpty &&
        items.every((WindowReviewItem item) => item.unitMode == UnitMode.cm);
    return OptimizationRequest(
      projectId: projectId,
      context: context,
      displayUnit: allCm ? 'cm' : displayUnit,
      projectName: projectName,
      projectLocation: projectLocation,
      windows: items
          .map(
            (WindowReviewItem item) => OptimizationWindowRequest.fromReviewItem(
              item,
              isFabrication: isFabrication,
            ),
          )
          .toList(growable: false),
    );
  }

  /// The same job, with the app's own lengths attached to each window.
  OptimizationRequest withWindows(List<OptimizationWindowRequest> replaced) {
    return OptimizationRequest(
      projectId: projectId,
      context: context,
      displayUnit: displayUnit,
      projectName: projectName,
      projectLocation: projectLocation,
      windows: replaced,
    );
  }

  bool get isFabrication => context.toLowerCase() == 'fabrication';

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'context': context,
      'displayUnit': displayUnit,
      'projectId': projectId,
      'projectName': projectName,
      'projectLocation': projectLocation,
      'windows': windows
          .map((OptimizationWindowRequest item) => item.toJson())
          .toList(growable: false),
    };
  }
}
