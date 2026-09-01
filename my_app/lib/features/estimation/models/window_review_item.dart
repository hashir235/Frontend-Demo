import 'window_material.dart';

enum UnitMode { inches, feet, cm }

extension UnitModeLabels on UnitMode {
  String get label {
    switch (this) {
      case UnitMode.inches:
        return 'Inches';
      case UnitMode.feet:
        return 'Feet';
      case UnitMode.cm:
        return 'CM';
    }
  }

  String get inputHint {
    switch (this) {
      case UnitMode.inches:
        return 'inch.suter';
      case UnitMode.feet:
        return 'feet.inchs';
      case UnitMode.cm:
        return 'cm';
    }
  }

  String get wireValue {
    switch (this) {
      case UnitMode.inches:
        return 'inches';
      case UnitMode.feet:
        return 'feet';
      case UnitMode.cm:
        return 'cm';
    }
  }
}

UnitMode unitModeFromWireValue(String? value) {
  switch (value) {
    case 'inches':
      return UnitMode.inches;
    case 'cm':
      return UnitMode.cm;
    default:
      return UnitMode.feet;
  }
}

/// Converts a centimetre dimension string into the estimation engine's
/// "inch.sutter" wire encoding (sutter = eighths, 0..7), snapped to the
/// nearest 1/8 inch — the resolution of a real inch tape. 1 inch = 2.54 cm.
///
/// Estimation items entered in cm are STORED in cm (so review/editing show
/// the user's own numbers); this conversion is applied only when building
/// the optimization request, because the estimation engine understands
/// inches/feet.
String cmDimensionToInchSutter(String cmText) {
  final double cm = double.tryParse(cmText.trim()) ?? 0;
  if (cm <= 0) {
    return '0.0';
  }
  final double totalInches = cm / 2.54;
  int inch = totalInches.floor();
  int sutter = ((totalInches - inch) * 8).round();
  if (sutter >= 8) {
    inch += 1;
    sutter = 0;
  }
  return '$inch.$sutter';
}

/// Door frame ke peeche wala collar sirf do naap ka hota ha.
const double kBackCollarDefaultCm = 1.7;
const double kBackCollarTwoCm = 2.0;

/// Jo bhi aur value aaye, use purana 1.7cm hi mana jata ha.
double backCollarFromJson(Object? value) {
  final double? parsed = value is num
      ? value.toDouble()
      : double.tryParse('$value');
  return parsed == kBackCollarTwoCm ? kBackCollarTwoCm : kBackCollarDefaultCm;
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

  /// Door frame ke peeche wala collar: 1.7 (purana) ya 2.0 (naya).
  final double backCollarCm;
  final int? lockType;
  final String? rubberType;
  final String? description;

  /// The aluminium this window is cut from. Per window, so one job can carry
  /// 2mm outer frames and 1.2mm partitions, or a door in another colour --
  /// which is what a real job usually looks like.
  ///
  /// A window read back from a project saved before this was per-window has no
  /// stock of its own; it takes the pair that job was estimated at, so
  /// reopening old work shows exactly what it always showed.
  final WindowMaterial material;

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
    this.backCollarCm = 1.7,
    this.lockType,
    this.rubberType,
    this.description,
    this.material = WindowMaterial.initial,
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
    double? backCollarCm,
    int? lockType,
    String? rubberType,
    String? description,
    WindowMaterial? material,
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
      backCollarCm: backCollarCm ?? this.backCollarCm,
      lockType: clearLockType ? null : (lockType ?? this.lockType),
      rubberType: clearRubberType ? null : (rubberType ?? this.rubberType),
      description: clearDescription ? null : (description ?? this.description),
      material: material ?? this.material,
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
      backCollarCm: backCollarFromJson(json['backCollarCm']),
      lockType: json['lockType'] == null ? null : _asInt(json['lockType']),
      rubberType: (json['rubberType'] as String?)?.trim(),
      description: (json['description'] as String?)?.trim(),
      // Left genuinely empty when the window was saved before stock was per
      // window, rather than guessed at as 1.2mm champagne. A job estimated
      // wholly in 2mm black would otherwise reopen claiming every window was
      // champagne -- a confident wrong answer, which is worse than none.
      // EstimateSessionStore.restoreOutputs fills these in from the pair that
      // job was actually estimated at.
      material: WindowMaterial(
        gauge: (json['gauge'] as String? ?? '').trim(),
        color: (json['color'] as String? ?? '').trim(),
      ),
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
      'backCollarCm': backCollarCm,
      'lockType': lockType,
      'rubberType': rubberType,
      'description': description,
      // The engine keys its cutting piles and its rates on these, so they
      // travel with every window on every request.
      'gauge': material.gauge,
      'color': material.color,
    };
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }
}
