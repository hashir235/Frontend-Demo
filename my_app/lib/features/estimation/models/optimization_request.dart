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
    return OptimizationWindowRequest(
      winNo: item.winNo,
      windowCode: item.windowCode,
      windowLabel: item.windowLabel,
      collarIndex: item.collarIndex,
      unitMode: unitMode,
      heightValue: dim(item.heightValue),
      widthValue: dim(item.widthValue),
      rightWidthValue: dimOrNull(item.rightWidthValue),
      leftWidthValue: dimOrNull(item.leftWidthValue),
      archValue: dimOrNull(item.archValue),
      description: item.description,
      addBottom: item.addBottom,
      addTee: item.addTee,
      addNet: item.addNet,
      backCollarCm: item.backCollarCm,
      lockType: item.lockType,
      rubberType: item.rubberType,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
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
