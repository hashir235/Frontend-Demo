enum UnitMode { inches, feet }

extension UnitModeLabels on UnitMode {
  String get label => this == UnitMode.inches ? 'Inches' : 'Feet';

  String get inputHint => this == UnitMode.inches ? 'inch.suter' : 'feet.inchs';
}

class WindowReviewItem {
  final int winNo;
  final String windowLabel;
  final String windowCode;
  final int windowIndex;
  final int collarIndex;
  final UnitMode unitMode;
  final String heightValue;
  final String widthValue;
  final String? rightWidthValue;
  final String? leftWidthValue;
  final String? description;

  const WindowReviewItem({
    required this.winNo,
    required this.windowLabel,
    required this.windowCode,
    required this.windowIndex,
    required this.collarIndex,
    required this.unitMode,
    required this.heightValue,
    required this.widthValue,
    this.rightWidthValue,
    this.leftWidthValue,
    this.description,
  });

  WindowReviewItem copyWith({
    int? winNo,
    String? windowLabel,
    String? windowCode,
    int? windowIndex,
    int? collarIndex,
    UnitMode? unitMode,
    String? heightValue,
    String? widthValue,
    String? rightWidthValue,
    String? leftWidthValue,
    String? description,
    bool clearDescription = false,
    bool clearRightWidthValue = false,
    bool clearLeftWidthValue = false,
  }) {
    return WindowReviewItem(
      winNo: winNo ?? this.winNo,
      windowLabel: windowLabel ?? this.windowLabel,
      windowCode: windowCode ?? this.windowCode,
      windowIndex: windowIndex ?? this.windowIndex,
      collarIndex: collarIndex ?? this.collarIndex,
      unitMode: unitMode ?? this.unitMode,
      heightValue: heightValue ?? this.heightValue,
      widthValue: widthValue ?? this.widthValue,
      rightWidthValue: clearRightWidthValue
          ? null
          : (rightWidthValue ?? this.rightWidthValue),
      leftWidthValue: clearLeftWidthValue
          ? null
          : (leftWidthValue ?? this.leftWidthValue),
      description: clearDescription ? null : (description ?? this.description),
    );
  }
}
