enum UnitMode { inches, feet }

extension UnitModeLabels on UnitMode {
  String get label => this == UnitMode.inches ? 'Inches' : 'Feet';

  String get inputHint => this == UnitMode.inches ? 'inch.suter' : 'feet.inchs';

  String get wireValue => this == UnitMode.inches ? 'inches' : 'feet';
}

UnitMode unitModeFromWireValue(String? value) {
  return value == 'inches' ? UnitMode.inches : UnitMode.feet;
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
  final String? archValue;
  final bool addBottom;
  final bool addTee;
  final bool addNet;
  final int? lockType;
  final String? rubberType;
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
    this.archValue,
    this.addBottom = false,
    this.addTee = false,
    this.addNet = false,
    this.lockType,
    this.rubberType,
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
    String? archValue,
    bool? addBottom,
    bool? addTee,
    bool? addNet,
    int? lockType,
    String? rubberType,
    String? description,
    bool clearDescription = false,
    bool clearRightWidthValue = false,
    bool clearLeftWidthValue = false,
    bool clearArchValue = false,
    bool clearLockType = false,
    bool clearRubberType = false,
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
      archValue: clearArchValue ? null : (archValue ?? this.archValue),
      addBottom: addBottom ?? this.addBottom,
      addTee: addTee ?? this.addTee,
      addNet: addNet ?? this.addNet,
      lockType: clearLockType ? null : (lockType ?? this.lockType),
      rubberType: clearRubberType ? null : (rubberType ?? this.rubberType),
      description: clearDescription ? null : (description ?? this.description),
    );
  }

  factory WindowReviewItem.fromJson(Map<String, dynamic> json) {
    return WindowReviewItem(
      winNo: _asInt(json['winNo']),
      windowLabel: (json['windowLabel'] as String? ?? '').trim(),
      windowCode: (json['windowCode'] as String? ?? '').trim(),
      windowIndex: _asInt(json['windowIndex']),
      collarIndex: _asInt(json['collarIndex']),
      unitMode: unitModeFromWireValue(json['unitMode'] as String?),
      heightValue: (json['heightValue'] as String? ?? '').trim(),
      widthValue: (json['widthValue'] as String? ?? '').trim(),
      rightWidthValue: (json['rightWidthValue'] as String?)?.trim(),
      leftWidthValue: (json['leftWidthValue'] as String?)?.trim(),
      archValue: (json['archValue'] as String?)?.trim(),
      addBottom: json['addBottom'] == true,
      addTee: json['addTee'] == true,
      addNet: json['addNet'] == true,
      lockType: json['lockType'] == null ? null : _asInt(json['lockType']),
      rubberType: (json['rubberType'] as String?)?.trim(),
      description: (json['description'] as String?)?.trim(),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'winNo': winNo,
      'windowLabel': windowLabel,
      'windowCode': windowCode,
      'windowIndex': windowIndex,
      'collarIndex': collarIndex,
      'unitMode': unitMode.wireValue,
      'heightValue': heightValue,
      'widthValue': widthValue,
      'rightWidthValue': rightWidthValue,
      'leftWidthValue': leftWidthValue,
      'archValue': archValue,
      'addBottom': addBottom,
      'addTee': addTee,
      'addNet': addNet,
      'lockType': lockType,
      'rubberType': rubberType,
      'description': description,
    };
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }
}
